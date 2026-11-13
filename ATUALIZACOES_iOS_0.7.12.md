# Registro de Atualizações — Downhill Revived iOS (v0.7.12)

Este documento registra as melhorias, correções de jogabilidade e compatibilidade implementadas nesta versão para iOS.

---

## 1. Atualização com Upstream (v0.7.12)
- O projeto foi sincronizado e atualizado com as correções e melhorias da versão oficial **0.7.12** do repositório base: [https://github.com/skuza-oss/downhill-revived](https://github.com/skuza-oss/downhill-revived).
- Inclui otimizações no renderizador Metal/Rust, estabilidade da emulação HLE e correções de áudio e desempenho geral.

---

## 2. Correção do Analógico do Controle Bluetooth (Movimentos Suaves)
- **Problema Corrigido**: Ao utilizar controles físicos Bluetooth (Game Controller / DualShock / DualSense / Xbox / MFi), o analógico não respondia a inclinações leves ou movimentos mais suaves, exigindo que o jogador empurrasse o stick quase até o limite para que a bicicleta começasse a virar.
- **Melhoria Implementada**:
  - Ajustada a curva de leitura e normalização dos eixos analógicos (`GCControllerDirectionPad` / `GCControllerAxisInput`).
  - Calibração da zona morta (*deadzone*) e linearidade na conversão dos eixos para os registros de entrada do PS2 (`stick.h` / `touch_input.m`).
  - Agora o controle responde a micro-ajustes de direção com total precisão e sensibilidade progressiva, garantindo controle refinado nas curvas rápidas e técnicas.

---

## 3. Correção Visual do HUD: Alinhamento do Texto de Combate ("PUNCH", "KICK")
- **Problema Corrigido**: Em telas ultrawide (como iPhone 17 Pro Max / formato ~2.17:1), o texto de ação de combate (`"PUNCH"`, `"KICK"`) ficava deslocado para baixo, fora da faixa sombreada preta 3D acima do velocímetro.
- **Causa Raiz**:
  - Incompatibilidade de modo de arredondamento de ponto flutuante durante a rotação da tela: no boot em modo retrato usava `FE_TONEAREST` da CPU ARM64, e ao girar para paisagem na largada da corrida executava sob `FE_TOWARDZERO` do EE, gerando 1 ULP de diferença no float esperado.
  - Isso fazia a rotina de widescreen ignorar a atualização das palavras de projeção 3D (`0x27ECE0`), encolhendo a projeção 3D verticalmente em 18,2% enquanto o texto 2D permanecia na posição original.
- **Solução Implementada**:
  - Rastreamento confiável de descritores de projeção aplicados em `port/hle/widescreen.c`.
  - Projeção 3D e HUD 2D agora mantêm sincronia e alinhamento perfeitos em qualquer proporção de tela ou resolução ultrawide.

---

## 4. Ajustes Ergonômicos do Joystick Virtual de Toque (Touch Stick)
- **Posicionamento e Margem Segura**:
  - Ajustado o layout padrão do analógico em `port/ios/launcher/TouchLayout.swift` para respeitar a safe area, evitando cortes na borda esquerda da tela e na Dynamic Island em modo paisagem.
  - Otimizada a área de descanso para o polegar esquerdo.
- **Resposta ao Toque Imediato**:
  - Otimizada a rotina de detecção em `ImmediateTouchInput.swift` e `touch_input.m`, garantindo transição suave ao arrastar e limitador de raio radial calibrado.

---

## 5. Portabilidade do Projeto Xcode
- Configuração do projeto Xcode (`build/ios/project/DownhillRevived.xcodeproj`) com equipe neutra (`DEVELOPMENT_TEAM: ""`), permitindo abrir e compilar em qualquer Mac diretamente selecionando seu próprio perfil no Xcode sem conflitos de provisionamento.
