type amountDetails = {
  amount_per_installment: int,
  total_amount: int,
}

type installmentPlan = {
  interest_rate: float,
  number_of_installments: int,
  billing_frequency: string,
  amount_details: amountDetails,
}

type installmentOption = {
  payment_method: string,
  available_plans: array<installmentPlan>,
}
