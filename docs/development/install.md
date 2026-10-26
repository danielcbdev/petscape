# Installing PetScape

## English

PetScape v1.0.2 provides a **universal app for Apple silicon and Intel Macs with macOS 14 or later**.
No Xcode, Git or project checkout is needed. Native Intel execution and clean-machine installation
on macOS 14–26 remain unverified; both executable slices are cross-built and signature-checked.

**Read this before the first open:** this app is ad-hoc signed and **not notarized**. macOS may say
**“Apple could not verify PetScape.app is free of malware”**. If you independently trust the official
download and accept the risk, try opening it once from Applications, dismiss that warning, then go
to **System Settings → Privacy & Security → Security → Open Anyway**. Authenticate if asked and
confirm **Open** in the next dialog. The paw icon appears in the menu bar. This is your app-specific
approval, not Apple verification. If macOS reports damage/malware or offers no override, stop and
consult the project owner/administrator. Availability depends on OS/device policy.

The DMG and ZIP include these instructions as **INSTALL-FIRST.txt**, which Finder opens in
TextEdit without a Markdown viewer. Keep them open while installing if needed.

1. Download **PetScape-1.0.2-12-universal.dmg** from the
   [official release](https://github.com/danielcbdev/petscape/releases/tag/v1.0.2).
   Select the DMG under **Assets**, rather than GitHub's Source code archives.
2. For recommended integrity verification, download the matching `.dmg.sha256` file to the same
   folder. In Terminal, change to that folder and run:

   ```bash
   shasum -a 256 -c PetScape-1.0.2-12-universal.dmg.sha256
   ```

   Expect the DMG filename followed by `OK`. If it fails, stop: check that both files belong to
   the same version/build, download both again from the official release and retry. Do not open
   an app from a mismatched download; report a persistent mismatch to the project owner.
3. Open the DMG. Quit any running PetScape, then drag **PetScape.app** onto the **Applications**
   shortcut. Confirm replacement for an upgrade. Back up preferences and installed packs before
   upgrading; they remain in your user account and replacing the app does not intentionally remove
   them. There is no automatic updater or migration guarantee for downgrades.
4. Eject the **PetScape 1.0.2** disk image in Finder. Open **Applications → PetScape**. It appears as
   a **paw icon in the menu bar**, without a Dock icon. Open **Settings…** from that menu.

### Download with Terminal, like MacDevClean

Run these together; a failed download or checksum stops before the disk image opens:

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

After `OK`, drag the app to Applications, eject the DMG and follow the first-open steps above.
This is the same package as the browser download; no extra runtime or source checkout is needed.
It changes no quarantine attributes or global security setting and guarantees no warning-free launch.

An alternative ZIP is available. Download it and its own `.zip.sha256` file, verify with
`shasum -a 256 -c PetScape-1.0.2-12-universal.zip.sha256`, extract and drag the app to Applications.
ZIP installation has no disk image to eject. `SHA256SUMS` lists **both DMG and ZIP**, so checking
that combined file requires both downloads. A format-specific checksum checks only your chosen file.

Both formats contain `CONTENTS.sha256`; from the mounted DMG or extracted ZIP folder, optionally
run `shasum -a 256 -c CONTENTS.sha256` to check the app, notes and license files. Every entry must
report `OK`. The DMG's Applications shortcut is separately validated during packaging. A checksum
detects accidental corruption; if someone replaces package and checksum on the same channel, it
**does not** independently authenticate their source.

The app is **ad-hoc signed**. This signature checks bundle integrity, identifies no developer and
is not an Apple trust endorsement. PetScape is **not notarized**. Depending on macOS version and
security policy, a downloaded copy can warn that the developer cannot be verified or Apple cannot
check the app, or be blocked. Successful checksum/signature verification does not prove it safe.

If you independently decide to trust this source after reviewing the warning, Apple's documented
flow may offer **System Settings → Privacy & Security → Open Anyway** after an attempted launch.
Read the warning, choose Open Anyway only if you accept the risk, authenticate when asked and
confirm opening. This is your explicit security exception; it is not notarization or Apple validation.
Labels and availability differ by macOS release and managed-device policy. If macOS reports
malware/damage or no override is offered, stop and consult the project owner or administrator.
Do not change global security policy. See [Apple's opening guidance](https://support.apple.com/en-us/102445).

Basic overlay/manual behavior requires no privacy permission. Window interaction and music
recognition have separate opt-in consent flows. Replacing an ad-hoc signed build can require
reauthorizing optional OS permissions and reviewing the login item.

Verification: universal packaging, DMG read-only mounting, ZIP extraction, per-slice signatures and
checksums were exercised on macOS 27.0.1 / Xcode 27.1 and the v1.0.0 hosted package on Xcode 26.2.
The owner reported the Apple verification warning when opening v1.0.0; the exact OS/download
route and a successful approval/relaunch were not recorded. A complete clean-machine first-launch
Gatekeeper flow remains **unverified**, as do managed Macs and older supported OS versions.
No warning-free launch or universally available override is promised. Published v1.0.1 retains its
historical release-only V8 exception. The owner subsequently closed the visual follow-up on
2026-10-25: the exact artwork/findings are now an approved regression baseline in the current
checkout, with original pixel assertions still evaluated and no claim of repaired pixels.

## Brazilian Portuguese installation copy

O PetScape v1.0.2 oferece um app **universal para Macs Apple silicon e Intel com macOS 14 ou
posterior**. Não é preciso Xcode, Git, baixar o projeto ou compilar. A execução em hardware Intel
e a instalação limpa no macOS 14–26 ainda não foram verificadas; as duas arquiteturas são
compiladas e têm a assinatura conferida.

**Antes da primeira abertura:** este app tem assinatura ad-hoc e **não foi notarizado**. O macOS
pode mostrar **“A Apple não pôde verificar se o item PetScape.app está livre de algum malware
capaz de danificar o Mac ou comprometer sua privacidade”**.

Se você confia na origem oficial e aceita o risco:

1. Tente abrir **Aplicativos → PetScape** uma vez e feche esse aviso.
2. Entre em **Ajustes do Sistema → Privacidade e Segurança** e role até **Segurança**.
3. Na mensagem sobre o PetScape, clique em **Abrir Mesmo Assim**, autentique-se se solicitado e
   confirme **Abrir** na próxima janela.
4. Procure o ícone de pata na barra de menus; o app não aparece no Dock.

Essa é uma autorização específica escolhida por você, sem equivaler à aprovação da Apple. Se o
macOS indicar malware/dano ou não oferecer essa opção, pare e consulte o responsável/administrador.
O arquivo **INSTALL-FIRST.txt** dentro do DMG/ZIP abre no TextEdit e contém estas instruções.

1. Na [release oficial](https://github.com/danielcbdev/petscape/releases/tag/v1.0.2), abra **Assets**
   e baixe **PetScape-1.0.2-12-universal.dmg**. Os links **Source code** são para desenvolvimento.
2. Para conferir a integridade, baixe também o arquivo `.dmg.sha256` correspondente para a mesma
   pasta. No Terminal, entre nessa pasta e execute:

   ```bash
   shasum -a 256 -c PetScape-1.0.2-12-universal.dmg.sha256
   ```

   O resultado deve mostrar o nome do DMG e `OK`. Se falhar, não abra o app: confira versão/build,
   baixe os dois arquivos novamente da release oficial e repita. Se persistir, avise o responsável.
3. Abra o DMG. Encerre qualquer cópia do PetScape em execução e arraste **PetScape.app** para o
   atalho **Applications / Aplicativos**. Confirme a substituição ao atualizar. Faça backup das
   preferências e pacotes instalados antes; eles permanecem na sua conta. Não há atualização
   automática nem garantia de migração ao voltar para uma versão anterior.
4. Ejete o disco **PetScape 1.0.2** no Finder e abra **Aplicativos → PetScape**. Procure o **ícone de
   pata na barra de menus**: não há ícone no Dock. Abra **Ajustes…** nesse menu.

Para baixar pelo mesmo método do MacDevClean, execute o bloco de comandos da seção
**Download with Terminal, like MacDevClean** acima. Ele baixa o DMG e o checksum, exige resultado
`OK` antes de abrir o disco e não exige Xcode, Git, Python ou o projeto local. Depois arraste o app
para Aplicativos e siga a aprovação descrita acima, se aparecer. É o mesmo pacote oferecido no
navegador, sem mudança na assinatura ou notarização e sem garantia de ausência do alerta.

Há também um ZIP: baixe-o junto com o seu `.zip.sha256`, execute
`shasum -a 256 -c PetScape-1.0.2-12-universal.zip.sha256`, extraia e arraste o app para Aplicativos.
Nesse formato não há disco para ejetar. `SHA256SUMS` confere **os dois formatos** e exige ambos os
arquivos; use o checksum específico se baixou apenas um. Dentro do disco montado ou pasta extraída,
`shasum -a 256 -c CONTENTS.sha256` confere os arquivos internos. Todos devem indicar `OK`.
Checksum detecta corrupção acidental; não autentica a origem de forma independente se pacote e
checksum forem substituídos no mesmo canal.

A assinatura é **ad-hoc**, sem identificar o desenvolvedor nem representar aprovação da Apple.
O app **não foi notarizado**. O Gatekeeper pode avisar que o desenvolvedor não foi verificado,
que a Apple não pode verificar o app, ou bloquear a abertura, conforme a versão e a política do Mac.

Se você decidiu confiar na origem e aceita o risco, após tentar abrir o app o próprio macOS pode
oferecer **Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo Assim** (Open Anyway).
Leia o aviso, escolha a opção apenas se concordar, autentique-se se solicitado e confirme a abertura.
É uma exceção escolhida por você, sem equivaler a notarização ou validação da Apple. A disponibilidade
varia por versão e por políticas de computadores gerenciados. Em caso de aviso de malware/dano ou
se a opção não aparecer, interrompa e consulte o responsável pelo projeto ou administrador, sem
alterar a política global de segurança. Consulte as [orientações da Apple](https://support.apple.com/pt-br/102445).

As funções básicas não exigem permissão especial. Interação com janelas e detecção de música têm
consentimentos opcionais separados. Uma atualização ad-hoc pode exigir nova autorização dessas
permissões e revisão do item de início de sessão.

Verificado: empacotamento universal, montagem somente leitura do DMG, extração do ZIP, assinaturas
e checksums no macOS 27.0.1 / Xcode 27.1 e no pacote v1.0.0 do CI com Xcode 26.2. O proprietário
relatou o alerta de verificação da Apple na v1.0.0; versão do sistema, forma do download e abertura
após aprovação não foram registradas. O fluxo completo de primeira abertura em Mac limpo permanece
**não verificado**, assim como outros sistemas/dispositivos gerenciados. A release publicada v1.0.1
mantém sua exceção V8 histórica. O proprietário encerrou e aprovou a pendência visual em 2026-10-25:
as imagens e os achados exatos agora compõem o baseline de regressão da versão em desenvolvimento,
com as verificações de pixels preservadas, sem alegar correção dos pixels.
