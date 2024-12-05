type payment =
  | Card
  | BankTransfer
  | BankDebits
  | KlarnaRedirect
  | Gpay
  | Applepay
  | Paypal
  | Samsungpay
  | Paze
  | Other

type paymentIntent = (
  ~handleUserError: bool=?,
  ~bodyArr: array<(string, JSON.t)>,
  ~confirmParam: ConfirmType.confirmParams,
  ~iframeId: string=?,
  ~isThirdPartyFlow: bool=?,
  ~intentCallback: Core__JSON.t => unit=?,
  ~manualRetry: bool=?,
) => unit

type completeAuthorize = (
  ~handleUserError: bool=?,
  ~bodyArr: array<(string, JSON.t)>,
  ~confirmParam: ConfirmType.confirmParams,
  ~iframeId: string=?,
) => unit
