//
//  FinTrackTests.swift
//  FinTrackTests
//
//  Created by Nilupul Rambukwelle on 2026-10-10.
//

import Testing
@testable import FinTrack

struct FinTrackTests {
    @Test("Goals count income and expenses in the same category")
    func goalContributionsUseAbsoluteTransactionValues() {
        let amounts = [2_000.0, -500.0, -275.0]
        let contribution = amounts.reduce(0) {
            $0 + FinancialMath.goalContribution(for: $1)
        }

        #expect(contribution == 2_775)
    }

    @Test("Budgets count expenses but ignore income")
    func budgetSpendingIgnoresIncome() {
        let amounts = [-1_250.0, 400.0, -50.0]
        let spent = amounts.reduce(0) {
            $0 + FinancialMath.budgetSpending(for: $1)
        }

        #expect(spent == 1_300)
    }

    @Test(arguments: [
        (amount: 500.0, isExpense: false, expected: 500.0),
        (amount: 500.0, isExpense: true, expected: -500.0),
        (amount: -500.0, isExpense: false, expected: 500.0),
        (amount: -500.0, isExpense: true, expected: -500.0)
    ])
    func recurringAmountsHaveTheCorrectSign(
        amount: Double,
        isExpense: Bool,
        expected: Double
    ) {
        #expect(
            FinancialMath.signedRecurringAmount(
                amount: amount,
                isExpense: isExpense
            ) == expected
        )
    }
}
