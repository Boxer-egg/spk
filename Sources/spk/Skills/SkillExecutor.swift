import Foundation

class SkillExecutor {
    static let shared = SkillExecutor()

    func execute(calls: [SkillCall], originalText: String, completion: @escaping (Result<String, Error>) -> Void) {
        let context = SkillContext(originalText: originalText, text: originalText)

        // If no calls, fallback to default_paste behavior
        let effectiveCalls = calls.isEmpty ? [SkillCall(skill: "default_paste", args: [:])] : calls

        runStep(index: 0, calls: effectiveCalls, context: context) { result in
            switch result {
            case .success(let finalContext):
                completion(.success(finalContext.text))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func runStep(index: Int, calls: [SkillCall], context: SkillContext, completion: @escaping (Result<SkillContext, Error>) -> Void) {
        guard index < calls.count else {
            completion(.success(context))
            return
        }

        let call = calls[index]
        guard let skill = SkillRegistry.shared.skill(for: call.skill) else {
            print("Skill not found: \(call.skill)")
            runStep(index: index + 1, calls: calls, context: context, completion: completion)
            return
        }

        skill.execute(context: context, args: call.args) { result in
            switch result {
            case .success:
                self.runStep(index: index + 1, calls: calls, context: context, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
