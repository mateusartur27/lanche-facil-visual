import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../repositories/order_repository.dart';
import '../demo/demo_services.dart';

/// Carrega e apresenta a credencial de retirada sem persistir o token no aparelho.
class PickupQrDialog extends StatefulWidget {
  const PickupQrDialog({
    required this.repository,
    required this.establishmentId,
    required this.orderId,
    super.key,
  });

  final OrderRepository repository;
  final String establishmentId;
  final String orderId;

  @override
  State<PickupQrDialog> createState() => _PickupQrDialogState();
}

/// Mantém somente o estado temporário necessário enquanto o diálogo estiver aberto.
class _PickupQrDialogState extends State<PickupQrDialog> {
  PickupCredentialResult? _credential;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCredential();
  }

  /// Solicita uma nova credencial; isso invalida qualquer QR anterior do pedido.
  Future<void> _loadCredential() async {
    setState(() {
      _credential = null;
      _error = null;
    });
    try {
      final result = await widget.repository.issuePickupToken(
        establishmentId: widget.establishmentId,
        orderId: widget.orderId,
      );
      if (mounted) setState(() => _credential = result);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível gerar o QR de retirada. Tente novamente.');
      }
    }
  }

  /// Copia a mesma credencial do QR para permitir testes quando a câmera Web é bloqueada.
  Future<void> _copyPickupCode() async {
    final payload = _credential?.qrPayload;
    if (payload == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: payload));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código de retirada copiado.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Copiar código manualmente'),
          content: SelectableText(payload),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('QR Code de retirada'),
      // Limita o QR à área do diálogo e dispensa medições intrínsecas do LayoutBuilder.
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 112).clamp(160.0, 420.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_credential == null && _error == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Gerando credencial segura...'),
              ] else if (_error != null) ...[
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error, size: 42),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadCredential,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ] else ...[
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: (MediaQuery.sizeOf(context).width - 136)
                        .clamp(136.0, 290.0),
                    child: QrImageView(
                      key: const Key('pickup-qr-code'),
                      data: _credential!.qrPayload,
                      // Preserva a leitura mesmo com pequenos reflexos ou perda de foco.
                      errorCorrectionLevel: QrErrorCorrectLevel.Q,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  visualDemo
                      ? 'QR demonstrativo, sem validade para retirada real.'
                      : 'Apresente este código ao funcionário. A leitura não confirma '
                          'a entrega: os itens ainda serão conferidos antes da retirada.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_credential != null)
          OutlinedButton.icon(
            key: const Key('copy-pickup-code'),
            onPressed: _copyPickupCode,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar código'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
