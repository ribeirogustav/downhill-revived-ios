# Downhill Revived para iOS 0.7.16

O código-fonte parte da tag oficial [v0.7.16](https://github.com/skuza-oss/downhill-revived/releases/tag/v0.7.16), commit `f09710700edc1d11139fab766f700ebe47ba2abd`. A atualização inclui o núcleo, o renderer, o código de rede e os demais arquivos do projeto original.

O port conserva o launcher SwiftUI, a saída Metal, o suporte a tela externa e os controles do iOS. O editor salva uma escala de 25% a 600% por controle e mantém perfis distintos de iPhone e iPad em retrato e paisagem. No iPad, o tamanho padrão é 25% maior. A seleção por proximidade resolve a sobreposição entre botões, com rastreamento separado por dedo.

A integração de widescreen usa a tabela e a leitura de imediatos VU1 da versão oficial. No iOS, a troca de proporção em execução também atualiza os sprites já carregados na VU1, preservando a troca entre a tela do aparelho e a tela externa.

Na saída externa dedicada por HDMI ou AirPlay, o launcher ajusta o tamanho da interface à área útil da janela. Textos, botões e menus mantêm proporções semelhantes em 720p, 1080p e 4K. Em monitores muito largos, o conteúdo fica centralizado. A navegação continua no iPhone ou iPad.

## Compilar no Mac

Use Xcode com o SDK de iPhoneOS, XcodeGen, as ferramentas LLVM/WASI e WABT e o Rust indicado nos [requisitos de compilação](BUILDING.md). Coloque o executável extraído do seu próprio disco dos EUA em `iso/SCUS_971.77`. Se precisar, execute a etapa de extração descrita no guia. Para gerar um IPA sem assinatura com o núcleo reconstruído:

```sh
python3 port/ios/build_ios.py --rebuild-core --unsigned
```

### Gerar os dois IPAs de uma vez

Na raiz do projeto, rode `python3 GERAR_IPAS.py`. O script recompila o núcleo uma vez e gera os dois pacotes em `build/ios/`:

- `DownhillRevived-0.7.16-GitHub-unsigned.ipa` é a cópia pública sem assinatura.
- `DownhillRevived-0.7.16-Pessoal-signed.ipa` é a cópia assinada para os dispositivos autorizados no perfil de desenvolvimento.

Use o Team ID da sua conta Apple no Xcode. O script pede o ID no Terminal quando necessário. Você também pode passá-lo em `--team SEU_TEAM_ID` ou na variável `DHD_APPLE_TEAM`. Se o Xcode precisar criar ou atualizar o perfil, execute com `--allow-provisioning-updates`. Para direcionar a assinatura a um iPhone ou iPad pareado, passe `--device ID_DO_DISPOSITIVO`. A opção `--install` também instala a cópia assinada no dispositivo.

O ZIP contém código-fonte. A compilação nativa no Xcode e os testes de jogo no iPhone e no iPad ainda estão pendentes. A presença dos módulos de rede no código compartilhado não confirma a disponibilidade de corridas online no launcher iOS.
