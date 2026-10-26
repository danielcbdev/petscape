# Installing PetScape

## English

PetScape is a universal app for Apple silicon and Intel Macs running macOS 14 or later.
No Xcode, Git, Python, source checkout or manual download is required.

### Download, verify and open

Open Terminal and paste this entire block. It downloads the DMG and matching checksum, verifies
the file and opens the disk image. A failed download or checksum stops before opening.

```bash
mkdir -p "$HOME/Downloads/PetScape-1.0.2" &&
cd "$HOME/Downloads/PetScape-1.0.2" &&
curl --fail --location --proto '=https' --proto-redir '=https' \
  --output PetScape-1.0.2-12-universal.dmg \
  https://github.com/danielcbdev/petscape/releases/download/v1.0.2/PetScape-1.0.2-12-universal.dmg &&
curl --fail --location --proto '=https' --proto-redir '=https' \
  --output PetScape-1.0.2-12-universal.dmg.sha256 \
  https://github.com/danielcbdev/petscape/releases/download/v1.0.2/PetScape-1.0.2-12-universal.dmg.sha256 &&
shasum -a 256 -c PetScape-1.0.2-12-universal.dmg.sha256 &&
open PetScape-1.0.2-12-universal.dmg
```

When the checksum reports `OK`, the disk image opens:

1. Quit any running PetScape. Back up preferences and installed character packs before an upgrade.
2. Drag **PetScape.app** to **Applications** in the disk image. Confirm replacement if asked.
3. Eject **PetScape 1.0.2** and open **Applications → PetScape**.
4. Look for the **paw icon in the menu bar**. There is no Dock icon; open **Settings…** from the paw.

### First open

The app is **ad-hoc signed and not notarized**. macOS may say **“Apple could not verify
PetScape.app is free of malware”**. Signature/checksum checks verify integrity, not Apple approval.

If you independently trust the official source and accept the risk:

1. Try opening PetScape from Applications once and dismiss the warning.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, then choose **Open Anyway**
   for PetScape if macOS offers it.
3. Authenticate if asked and confirm **Open** in the next dialog.

This is your app-specific approval, not notarization or Apple verification. If macOS reports that
the app will damage your computer, says it is damaged, or offers no override, stop and consult the
project owner/administrator. Availability depends on OS/device policy. Follow
[Apple's guidance](https://support.apple.com/en-us/102445). No global security setting or quarantine
attribute is changed. No warning-free launch is promised.

### Verification, upgrades and alternatives

The Terminal block verifies the downloaded DMG automatically. A checksum mismatch must be resolved
before opening; repeat the whole block to fetch both matching files from the official release.
SHA-256 detects accidental corruption but cannot independently authenticate a source if both
package and checksum are replaced. Both packages also contain `CONTENTS.sha256` for an optional
internal check with `shasum -a 256 -c CONTENTS.sha256` from the mounted/extracted folder.

The [release page](https://github.com/danielcbdev/petscape/releases/tag/v1.0.2) also lists a ZIP and
its own `.zip.sha256`. The combined `SHA256SUMS` requires both formats; use a format-specific
checksum for one file. ZIP users extract the app and drag it to Applications.

Replacing the app preserves preferences/installed packs in your user account intentionally;
there is no automatic updater or downgrade migration guarantee. Optional window interaction and
music detection have separate consent flows; an ad-hoc update can require reauthorizing optional
permissions and reviewing the login item. Basic overlay/manual behavior needs no privacy permission.

`INSTALL-FIRST.txt` is this guide in native-readable plain text for TextEdit. The current artwork's
exact hashes and accepted known visual findings are recorded in `ARTWORK-ACCEPTANCE.json`.
Complete clean-machine approval/relaunch, native Intel execution, older supported OS and managed
policies remain unverified. Integrity/architecture checks do not establish those manual results.

## Português do Brasil

O PetScape é universal para Macs Apple silicon e Intel com macOS 14 ou posterior. Não é necessário
Xcode, Git, Python, baixar o projeto nem fazer download manual de arquivos.

### Baixar, verificar e abrir

Abra o Terminal e cole este bloco inteiro. Ele baixa o DMG e seu checksum, verifica a integridade
e abre a imagem de disco. Se o download ou checksum falhar, a sequência para antes da abertura.

```bash
mkdir -p "$HOME/Downloads/PetScape-1.0.2" &&
cd "$HOME/Downloads/PetScape-1.0.2" &&
curl --fail --location --proto '=https' --proto-redir '=https' \
  --output PetScape-1.0.2-12-universal.dmg \
  https://github.com/danielcbdev/petscape/releases/download/v1.0.2/PetScape-1.0.2-12-universal.dmg &&
curl --fail --location --proto '=https' --proto-redir '=https' \
  --output PetScape-1.0.2-12-universal.dmg.sha256 \
  https://github.com/danielcbdev/petscape/releases/download/v1.0.2/PetScape-1.0.2-12-universal.dmg.sha256 &&
shasum -a 256 -c PetScape-1.0.2-12-universal.dmg.sha256 &&
open PetScape-1.0.2-12-universal.dmg
```

Quando aparecer `OK`, a imagem de disco abrirá:

1. Encerre qualquer PetScape em execução. Faça backup das preferências e pacotes antes de atualizar.
2. Arraste **PetScape.app** para **Applications / Aplicativos** na imagem. Confirme a substituição.
3. Ejete **PetScape 1.0.2** e abra **Aplicativos → PetScape**.
4. Procure o **ícone de pata na barra de menus**. Não há ícone no Dock; abra **Ajustes…** pela pata.

### Primeira abertura

O app tem assinatura **ad-hoc** e **não foi notarizado**. O macOS pode mostrar **“A Apple não pôde
verificar se o item PetScape.app está livre de algum malware capaz de danificar o Mac ou comprometer
sua privacidade”**. Checksum e assinatura conferem integridade, sem equivaler à aprovação da Apple.

Se você confia na origem oficial e aceita o risco:

1. Tente abrir PetScape em Aplicativos uma vez e feche o aviso.
2. Acesse **Ajustes do Sistema → Privacidade e Segurança**, role até **Segurança** e escolha
   **Abrir Mesmo Assim** para o PetScape, se a opção estiver disponível.
3. Autentique-se se solicitado e confirme **Abrir** na próxima janela.

Essa aprovação é específica do app. Se o macOS disser que o app danificará o computador, estiver
danificado ou não oferecer a opção de abertura, pare e consulte o responsável/administrador.
A disponibilidade depende da versão e política do Mac. Consulte as
[orientações da Apple](https://support.apple.com/pt-br/102445). A instalação não muda a política
global de segurança nem atributos de quarentena, e não promete abertura sem alerta.

### Verificação e atualização

O bloco do Terminal já confere o checksum. Se falhar, repita o bloco para baixar os dois arquivos
correspondentes novamente; não abra antes de resolver. Checksum detecta corrupção, mas não autentica
a origem de forma independente se pacote e checksum forem substituídos juntos.

O arquivo `CONTENTS.sha256` permite conferir os arquivos internos com
`shasum -a 256 -c CONTENTS.sha256`. A release também oferece ZIP com checksum próprio; o
`SHA256SUMS` combinado exige ambos os formatos. Para atualizar, encerre a cópia antiga antes de
substituir. Preferências e pacotes permanecem na sua conta; não há atualização automática ou
garantia de migração ao voltar de versão. Permissões opcionais e item de início de sessão podem
exigir nova revisão após uma atualização ad-hoc.

`INSTALL-FIRST.txt` abre este guia no TextEdit. O registro `ARTWORK-ACCEPTANCE.json` documenta as
imagens e os achados visuais aceitos. Instalação limpa com aprovação/reabertura, execução nativa em
Intel e comportamento em sistemas antigos/dispositivos gerenciados permanecem não verificados.
