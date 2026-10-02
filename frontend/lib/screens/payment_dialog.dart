import '../demo/demo_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/product_service.dart';
import '../view_models/payment_view_model.dart';

/// Apresenta o QR Pix, acompanha a confirmação do provedor e oferece simulação local.
class PaymentDialog extends StatelessWidget {
  const PaymentDialog({
    required this.orderId,
    required this.formattedTotal,
    required this.viewModel,
    required this.simulationEnabled,
    super.key,
  });

  final String orderId;
  final String formattedTotal;
  final PaymentViewModel viewModel;
  final bool simulationEnabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) => AlertDialog(
        icon: Icon(
          viewModel.isConfirmed ? Icons.verified_rounded : Icons.pix_rounded,
          color: viewModel.isConfirmed ? Colors.green : null,
        ),
        title: Text(
          visualDemo
              ? 'Pix demonstrativo'
              : viewModel.isConfirmed
                  ? 'Pagamento confirmado'
                  : 'Pagamento Pix',
        ),
        // Uma largura limitada pela tela evita medir o QR por dimensões intrínsecas.
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 112).clamp(160.0, 480.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pedido: ${_shortOrderId(orderId)}'),
                Text('Valor: $formattedTotal'),
                const SizedBox(height: 16),
                Text(
                  visualDemo
                      ? 'Simulação offline. Não pague este QR. Nenhum valor será cobrado.'
                      : viewModel.isConfirmed
                          ? 'Pagamento confirmado pelo backend. O pedido foi enviado para preparação.'
                          : viewModel.charge != null
                              ? 'Escaneie o QR Code no aplicativo do seu banco ou use o Pix Copia e Cola. Esta tela reconhecerá a aprovação automaticamente.'
                              : viewModel.isLoading
                                  ? 'Buscando a cobrança Pix vinculada a este pedido...'
                                  : simulationEnabled
                                      ? 'Este ambiente utiliza uma confirmação fictícia, sem movimentar dinheiro real.'
                                      : 'A cobrança Pix real será exibida quando o provedor de pagamento estiver conectado.',
                ),
                if (viewModel.isLoading && viewModel.charge == null) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (viewModel.charge != null && !viewModel.isConfirmed) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(
                        data: viewModel.charge!.qrCode,
                        size:
                            MediaQuery.sizeOf(context).width < 360 ? 160 : 210,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Pix Copia e Cola'),
                    child: SelectableText(
                      viewModel.charge!.qrCode,
                      maxLines: 3,
                    ),
                  ),
                ],
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    viewModel.errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!viewModel.isConfirmed && viewModel.charge == null)
            FilledButton.icon(
              key: const Key('create-pix-charge'),
              onPressed: viewModel.isLoading
                  ? null
                  : () => viewModel.createPixCharge(
                        establishmentId:
                            CatalogConfiguration.demonstrationEstablishmentId,
                        orderId: orderId,
                      ),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Gerar QR Code Pix'),
            ),
          if (viewModel.charge != null && !viewModel.isConfirmed)
            OutlinedButton.icon(
              key: const Key('copy-pix-code'),
              onPressed: () => _copyPixCode(context, viewModel.charge!.qrCode),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar código Pix'),
            ),
          if (simulationEnabled &&
              !viewModel.isConfirmed &&
              (visualDemo || viewModel.charge == null))
            FilledButton.icon(
              key: const Key('simulate-payment-approval'),
              onPressed: viewModel.isLoading
                  ? null
                  : () => viewModel.simulateApproval(
                        establishmentId:
                            CatalogConfiguration.demonstrationEstablishmentId,
                        orderId: orderId,
                      ),
              icon: viewModel.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined),
              label: const Text('Simular pagamento aprovado'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(viewModel.isConfirmed ? 'Concluir' : 'Fechar'),
          ),
        ],
      ),
    );
  }

  /// Evita substring inválida nos IDs curtos usados por testes em memória.
  String _shortOrderId(String value) {
    final limit = value.length < 8 ? value.length : 8;
    return value.substring(0, limit).toUpperCase();
  }

  /// Copia automaticamente em contextos seguros e oferece seleção manual no HTTP móvel.
  Future<void> _copyPixCode(BuildContext context, String pixCode) async {
    final localWebAddress = kIsWeb &&
        Uri.base.scheme != 'https' &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1';
    if (localWebAddress) {
      await _showManualCopyDialog(context, pixCode);
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: pixCode));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código Pix copiado.')),
        );
      }
    } catch (_) {
      // Alguns navegadores podem negar a permissão mesmo em HTTPS; a seleção mantém o fluxo útil.
      if (context.mounted) await _showManualCopyDialog(context, pixCode);
    }
  }

  /// Mostra o código em uma área selecionável quando o navegador bloqueia o clipboard.
  Future<void> _showManualCopyDialog(
    BuildContext context,
    String pixCode,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Copiar Pix manualmente'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'O navegador bloqueou a cópia automática neste link HTTP. '
                  'Pressione o código abaixo, selecione tudo e toque em Copiar.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  pixCode,
                  key: const Key('manual-pix-code'),
                ),
              ],
            ),
          ),
        ),
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
