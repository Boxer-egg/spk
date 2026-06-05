import Foundation
import CoreAudio
import AVFoundation

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let inputChannels: UInt32
    let outputChannels: UInt32
    var isInputDevice: Bool { inputChannels > 0 }
}

class AudioDeviceManager {
    static let shared = AudioDeviceManager()

    func enumerateInputDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceIDs)

        return deviceIDs.compactMap { deviceID in
            guard let name = getStringProperty(id: deviceID, selector: kAudioDevicePropertyDeviceNameCFString),
                  let uid = getStringProperty(id: deviceID, selector: kAudioDevicePropertyDeviceUID) else {
                return nil
            }
            let inputs = channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput)
            let outputs = channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput)
            guard inputs > 0 else { return nil }
            return AudioDevice(id: deviceID, name: name, uid: uid, inputChannels: inputs, outputChannels: outputs)
        }
    }

    func deviceForUID(_ uid: String) -> AudioDevice? {
        guard !uid.isEmpty else { return nil }
        return enumerateInputDevices().first { $0.uid == uid }
    }

    /// Binds the AVAudioEngine to the device with the given UID.
    /// If uid is empty, clears any custom binding (uses system default).
    /// Returns true if successful.
    @discardableResult
    func bindEngine(_ engine: AVAudioEngine, toDeviceUID uid: String) -> Bool {
        if let device = deviceForUID(uid) {
            // Try private setDevice: API first (does not affect system default)
            if bindEngineToDevice(engine, deviceID: device.id) {
                return true
            }
            // Do NOT fallback to changing system default input device,
            // as that affects all applications globally.
            return false
        } else {
            // empty means system default; clear custom binding
            return clearEngineBinding(engine)
        }
    }

    // MARK: - Private helpers

    private func bindEngineToDevice(_ engine: AVAudioEngine, deviceID: AudioDeviceID) -> Bool {
        guard let audioUnit = engine.inputNode.audioUnit else { return false }
        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        return status == noErr
    }

    private func clearEngineBinding(_ engine: AVAudioEngine) -> Bool {
        guard let audioUnit = engine.inputNode.audioUnit else { return false }
        var devID = AudioDeviceID(0)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        return status == noErr
    }

    private func setDefaultInputDevice(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &id
        )
        return status == noErr
    }

    private func getStringProperty(id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var result: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &result) { ptr in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
        }
        guard status == noErr else { return nil }
        return result as String?
    }

    private func channelCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return 0
        }

        let mem = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))
        defer { mem.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, mem) == noErr else {
            return 0
        }

        let abl = UnsafeMutableAudioBufferListPointer(
            mem.withMemoryRebound(to: AudioBufferList.self, capacity: 1) { $0 }
        )
        return abl.reduce(0) { $0 + $1.mNumberChannels }
    }

    // MARK: - Device Change Observation

    private var deviceChangeCallback: (() -> Void)?
    private let observerQueue = DispatchQueue(label: "spk.audio-device-observer")
    private var isObserving = false
    private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private lazy var listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        guard let self = self else { return }
        DispatchQueue.main.async {
            self.deviceChangeCallback?()
        }
    }

    func startListeningForDeviceChanges(onChange: @escaping () -> Void) {
        guard !isObserving else { return }
        deviceChangeCallback = onChange

        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        let devicesStatus = AudioObjectAddPropertyListenerBlock(
            systemObject, &devicesAddress, observerQueue, listenerBlock
        )
        let defaultInputStatus = AudioObjectAddPropertyListenerBlock(
            systemObject, &defaultInputAddress, observerQueue, listenerBlock
        )

        guard devicesStatus == noErr, defaultInputStatus == noErr else {
            if devicesStatus == noErr {
                AudioObjectRemovePropertyListenerBlock(systemObject, &devicesAddress, observerQueue, listenerBlock)
            }
            if defaultInputStatus == noErr {
                AudioObjectRemovePropertyListenerBlock(systemObject, &defaultInputAddress, observerQueue, listenerBlock)
            }
            return
        }
        isObserving = true
    }

    func stopListeningForDeviceChanges() {
        guard isObserving else { return }
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        AudioObjectRemovePropertyListenerBlock(systemObject, &devicesAddress, observerQueue, listenerBlock)
        AudioObjectRemovePropertyListenerBlock(systemObject, &defaultInputAddress, observerQueue, listenerBlock)
        isObserving = false
        deviceChangeCallback = nil
    }
}
