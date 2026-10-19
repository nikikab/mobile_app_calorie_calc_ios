import Foundation
import Observation
import KaloCalcCore

@MainActor
@Observable
final class CalculatorViewModel {
    private let model: AppModel
    private var stored: Profile

    var sex: Sex
    var age: String
    var height: String
    var weight: String
    var activity: ActivityLevel
    var goal: Goal
    var insulinResistance: Bool
    private(set) var plans: [GoalPlan] = []
    /// 0 when no saved goal is selected.
    private(set) var activePlanId: Int64 = 0
    var errorMessage: String?

    init(model: AppModel) {
        self.model = model
        let p = model.profileStore.profile
        stored = p
        sex = p.sex; age = String(p.age); height = String(p.heightCm); weight = gramsText(p.weightKg)
        activity = p.activity; goal = p.goal; insulinResistance = p.insulinResistance
        reload()
    }

    /// Fills the fields from what is saved; the weight may have changed on the Progress tab.
    func reload() {
        let p = model.profileStore.profile
        stored = p
        sex = p.sex; age = String(p.age); height = String(p.heightCm); weight = gramsText(p.weightKg)
        activity = p.activity; goal = p.goal; insulinResistance = p.insulinResistance
        perform { plans = try model.repository.plans() }
        activePlanId = model.profileStore.activePlanId
    }

    /// The profile as typed, or nil while a field is out of range.
    var parsed: Profile? {
        parseProfileInput(sex: sex, age: age, height: height, weight: weight, activity: activity, goal: goal, insulinResistance: insulinResistance)
    }

    var result: CalorieResult? { parsed.map(calculate) }

    /// What goals are calculated from: the typed profile, or the saved one while the fields are invalid.
    private var calcProfile: Profile {
        var p = parsed ?? stored
        p.insulinResistance = insulinResistance
        return p
    }

    var currentTarget: Int { calculate(calcProfile).target }
    var activePlan: GoalPlan? { plans.first { $0.id == activePlanId } }
    var targets: DayTargets { resolveTargets(profile: calcProfile, plans: plans, activeId: activePlanId) }

    func save() {
        guard let p = parsed else { return }
        model.profileStore.save(p)
        stored = p
    }

    func selectGoal(_ g: Goal) {
        goal = g
        model.profileStore.setBuiltInGoal(g)
        activePlanId = 0
    }

    func selectPlan(_ id: Int64) {
        model.profileStore.setActivePlan(id)
        activePlanId = id
    }

    /// A draft for "New goal": the numbers in force now.
    func newPlanDraft() -> GoalPlan {
        let m = targets.macros
        return GoalPlan(name: "", kcal: targets.kcal, proteinG: m.proteinG, carbsG: m.carbsG, fatG: m.fatG, baseKcal: currentTarget)
    }

    /// A plan with id 0 is new and becomes the selected goal; otherwise the stored one is replaced.
    func savePlan(_ plan: GoalPlan) {
        perform {
            if plan.id == 0 {
                selectPlan(try model.repository.insert(plan))
            } else {
                try model.repository.update(plan)
            }
            plans = try model.repository.plans()
        }
    }

    func deletePlan(_ plan: GoalPlan) {
        perform {
            if activePlanId == plan.id { selectPlan(0) }
            try model.repository.deletePlan(id: plan.id)
            plans = try model.repository.plans()
        }
    }

    private func perform(_ work: () throws -> Void) {
        do { try work() } catch { errorMessage = userMessage(for: error) }
    }
}
