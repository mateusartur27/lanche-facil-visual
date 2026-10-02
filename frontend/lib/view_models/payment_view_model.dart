import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/payment_repository.dart';

/// Mantém o estado da confirmação de pagamento fora dos componentes visuais.
class PaymentViewModel extends ChangeNotifier {
  PaymentViewModel({required PaymentRepository repository})
      : _repository = repository;

  final PaymentRepository _repository;
  bool isLoading = false;
  bool isConfirmed = false;
  PixChargeResult? charge;
  String? errorMessage;
  Timer? _pollingTimer;

  /// Impede que uma falha de rede deixe a tela presa indefinidamente em carregamento.
  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Solicita ao backend a cobrança que contém QR Code e Pix Copia e Cola.
  Future<void> createPixCharge({
    required String establishmentId,
    required String orderId,
  }) async {
    if (isLoading || charge != null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      charge = await _repository
          .createPixCharge(
            establishmentId: establishmentId,
            orderId: orderId,
          )
          .timeout(_requestTimeout);
      _startPolling(establishmentId: establishmentId, orderId: orderId);
    } on TimeoutException {
      errorMessage = 'O servidor demorou para responder. Tente novamente.';
    } catch (_) {
      errorMessage = 'Não foi possível gerar a cobrança Pix.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Solicita a confirmação local e traduz falhas para um estado apresentável.
  Future<void> simulateApproval({
    required String establishmentId,
    required String orderId,
  }) async {
    if (isLoading || isConfirmed) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository
          .simulateApproval(
            establishmentId: establishmentId,
            orderId: orderId,
          )
          .timeout(_requestTimeout);
      isConfirmed = true;
      _pollingTimer?.cancel();
    } on TimeoutException {
      errorMessage = 'O servidor demorou para responder. Tente novamente.';
    } catch (_) {
      errorMessage = 'Não foi possível confirmar o pagamento de teste.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Consulta periodicamente o backend enquanto a cobrança estiver aguardando pagamento.
  void _startPolling({
    required String establishmentId,
    required String orderId,
  }) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (isConfirmed || isLoading) return;
      try {
        final confirmed = await _repository.refreshPixPaymentStatus(
          establishmentId: establishmentId,
          orderId: orderId,
        );
        if (confirmed) {
          isConfirmed = true;
          _pollingTimer?.cancel();
          notifyListeners();
        }
      } catch (_) {
        // Uma falha temporária de consulta não apaga o QR nem interrompe o pagamento.
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
