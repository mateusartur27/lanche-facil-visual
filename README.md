# Lanche Fácil — visual do cliente

Aplicativo Flutter dedicado ao fluxo visual do cliente, com dados locais em memória.
Não possui Firebase, banco de dados, backend ou integração de pagamento.

## Fluxo disponível

Login e cadastro locais → catálogo e categorias → pesquisa → carrinho com observação → pedido → Pix simulado → preparação → histórico e QR demonstrativo de retirada.

Entre com qualquer e-mail válido e senha com pelo menos seis caracteres. Os dados são reiniciados quando o processo fecha. Pix e QR não têm validade operacional.

A faixa “DEMO OFFLINE” e as opções “Voltar ao meu painel” foram removidas.

## Executar e gerar APK

Instale o Flutter e o Android SDK. Na pasta `frontend`:

```powershell
# Obtém somente as bibliotecas usadas pelo visual.
flutter pub get
# Verifica o código e o fluxo em 320, 768 e 1440 pixels.
flutter analyze
flutter test
# Gera o APK instalável com assinatura local de desenvolvimento.
flutter build apk --release
# Alternativamente, abre o visual no navegador.
flutter run -d chrome
```

APK gerado: `frontend/build/app/outputs/flutter-apk/app-release.apk`.
Cópia pronta para instalação: `entregas/Lanche-Facil-Visual.apk`.

## Mapa do código

- `frontend/lib/main.dart`: inicialização, tema e navegação.
- `frontend/lib/screens/`: login, catálogo, pedidos, pagamento, retirada e informações do aplicativo.
- `frontend/lib/widgets/adaptive_navigation.dart`: menu responsivo do cliente.
- `frontend/lib/demo/demo_services.dart`: sessão, pedidos e pagamento em memória.
- `frontend/lib/models/`: modelos locais com valores em centavos.
- `frontend/lib/view_models/`: estado das telas e carrinho.
- `frontend/lib/services/`: contratos de sessão e catálogo embarcado.
- `frontend/lib/repositories/`: contratos de pedidos e pagamento simulados.
- `frontend/test/demo_flow_test.dart`: regressão do fluxo visual nas três larguras.
- `frontend/android/` e `frontend/web/`: configurações de compilação.

Versão 1.0.1+2 — 02/10/2026. Apenas a experiência de cliente está incluída.
