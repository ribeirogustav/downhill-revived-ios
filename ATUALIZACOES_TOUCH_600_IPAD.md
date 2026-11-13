# Controles touch individuais (25% a 600%) e padrão para iPad

O port iOS usa o código da versão oficial **0.7.16**.

- No launcher, abra **Personalizar controles** e toque em **Editar controles na tela**.
- Toque no botão na prévia ou escolha pelo menu **Controle**. O menu também lista os controles ocultos.
- Arraste o controle na prévia para mudar a posição. O painel de edição fica abaixo da prévia em retrato e ao lado em telas largas na horizontal.
- Ajuste **Tamanho** de **25% a 600%**, use **−/+** para passos de 10 pontos percentuais ou toque em **Voltar para 100%**.
- Em **Opções do controle**, você pode mudar a ação, a visibilidade ou a posição com precisão.
- Use **Desfazer** e **Refazer** no topo. Gire o aparelho para editar a outra orientação e toque em **Salvar** para gravar os ajustes.
- Botões, gatilhos, menu e analógico possuem escala independente.
- O analógico touch filtra pequenos desvios nas puxadas laterais ou verticais e mantém as diagonais para manobras.
- Os controles touch do iPad têm um **padrão próprio**, com botões cerca de 25% maiores e novo posicionamento para duas mãos. O iPhone mantém o seu padrão anterior.
- Existem quatro configurações independentes: iPhone em retrato/paisagem e iPad em retrato/paisagem, persistidas no arquivo `touch_layouts_v2.json`.
- Arquivos anteriores de layout v2 continuam legíveis. Em iPads, layouts antigos personalizados são preservados; os layouts não personalizados passam para o novo padrão de iPad.
- A seleção do controle ativo quando áreas de botões se sobrepõem leva em conta a proximidade do centro. Cada dedo aciona apenas um botão por vez, mas dedos diferentes podem manter ações simultâneas.
- O posicionamento de controles maiores que a tela continua possível, com recorte visual inevitável nas bordas.
- A escala do sistema touch legado foi limitada a 600% para manter a mesma faixa.

## Verificação

Testes de modelo Swift (geometria, escalas, JSON, migração e persistência) e os testes portáteis C/Python podem ser executados com:

```bash
python3 -m unittest discover -s port/ios/tests -v
```

**Limitação:** a funcionalidade UIKit de captura de toque e o desempenho real precisam ser verificados em um iPhone/iPad com Xcode. Este ZIP contém fontes, não um novo IPA. A compilação nativa é feita no Mac com o Xcode.
