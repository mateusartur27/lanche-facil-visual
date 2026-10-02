import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novo_ifood/main.dart';
import 'package:novo_ifood/demo/demo_services.dart';
import 'package:novo_ifood/models/order.dart';
import 'package:novo_ifood/screens/orders_screen.dart';
import 'package:novo_ifood/services/product_service.dart';

/// Verifica o checkout e o Pix local nas três larguras exigidas pelo projeto.
void main() {
  if (!visualDemo) return; // Este teste exercita somente o build demonstrativo.
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('fluxo visual offline em $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = DemoAuthService();
      await auth.signIn(email: 'visual@teste.com', password: '123456');
      await tester.pumpWidget(
          NovoIFood(authService: auth, productService: MemoryProductService()));
      await tester.pumpAndSettle();
      expect(find.text('DEMO OFFLINE'), findsNothing);
      expect(find.text('Voltar ao meu painel'), findsNothing);
      final button = find.widgetWithText(FilledButton, 'Adicionar').first;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      // A navegação ampla oferece Carrinho no menu; telas menores usam o ícone.
      final cart = find.byKey(const Key('open-cart'));
      await tester
          .tap(cart.evaluate().isNotEmpty ? cart : find.text('Carrinho').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('confirm-order')));
      await tester.tap(find.byKey(const Key('confirm-order')));
      await tester.pumpAndSettle();
      expect(find.text('Pix demonstrativo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-pix-charge')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copy-pix-code')), findsOneWidget);
      await tester.tap(find.byKey(const Key('simulate-payment-approval')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      final session = await auth.sessionChanges.first;
      final orders = await demoOrders
          .watchCustomerOrders(
              establishmentId:
                  CatalogConfiguration.demonstrationEstablishmentId,
              userId: session!.userId)
          .first;
      expect(orders.first.status, OrderStatus.awaitingPickup);
      expect(orders.first.totalAmount, greaterThan(0));
      // O histórico recebe o mesmo repositório usado pelo carrinho.
      await tester.pumpWidget(MaterialApp(
          home: OrdersScreen(
              session: session,
              repository: demoOrders,
              paymentRepository: demoPayments)));
      await tester.pumpAndSettle();
      final pickup = find.text('Mostrar QR de retirada').first;
      await tester.ensureVisible(pickup);
      await tester.tap(pickup);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pickup-qr-code')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
