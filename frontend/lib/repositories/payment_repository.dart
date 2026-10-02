/// Resultado confirmado pelo backend depois de processar a simulação local.
class PaymentApprovalResult {
  const PaymentApprovalResult({
    required this.orderId,
    required this.alreadyConfirmed,
  });

  final String orderId;
  final bool alreadyConfirmed;
}

/// Dados públicos necessários para apresentar a cobrança Pix ao cliente.
class PixChargeResult {
  const PixChargeResult({
    required this.orderId,
    required this.amount,
    required this.qrCode,
    required this.qrCodeBase64,
    this.ticketUrl,
  });

  final String orderId;
  final int amount;
  final String qrCode;
  final String qrCodeBase64;
  final String? ticketUrl;
}

/// Define a operação financeira consumida pelo ViewModel de pagamento.
abstract interface class PaymentRepository {
  /// Cria no backend uma cobrança Pix vinculada ao pedido autenticado.
  Future<PixChargeResult> createPixCharge({
    required String establishmentId,
    required String orderId,
  });

  /// Consulta pelo backend se o provedor já aprovou a cobrança.
  Future<bool> refreshPixPaymentStatus({
    required String establishmentId,
    required String orderId,
  });

  /// Solicita ao backend a confirmação simulada do pedido informado.
  Future<PaymentApprovalResult> simulateApproval({
    required String establishmentId,
    required String orderId,
  });
}
