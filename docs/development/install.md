# Installing PetScape

## English

PetScape v1.0.0 provides a **universal app for Apple silicon and Intel Macs with macOS 14 or later**.
No Xcode, Git or project checkout is needed. Native Intel execution and clean-machine installation
on macOS 14–26 remain unverified; both executable slices are cross-built and signature-checked.

1. Download **PetScape-1.0.0-10-universal.dmg** from the
   [official release](https://github.com/danielcbdev/petscape/releases/tag/v1.0.0).
   Select the DMG under **Assets**, rather than GitHub's Source code archives.
2. For recommended integrity verification, download the matching `.dmg.sha256` file to the same
   folder. In Terminal, change to that folder and run:

   ```bash
   shasum -a 256 -c PetScape-1.0.0-10-universal.dmg.sha256
   ```

   Expect the DMG filename followed by `OK`. If it fails, stop: check that both files belong to
   the same version/build, download both again from the official release and retry. Do not open
   an app from a mismatched download; report a persistent mismatch to the project owner.
3. Open the DMG. Quit any running PetScape, then drag **PetScape.app** onto the **Applications**
   shortcut. Confirm replacement for an upgrade. Back up preferences and installed packs before
   upgrading; they remain in your user account and replacing the app does not intentionally remove
   them. There is no automatic updater or migration guarantee for downgrades.
4. Eject the **PetScape 1.0.0** disk image in Finder. Open **Applications → PetScape**. It appears as
   a **paw icon in the menu bar**, without a Dock icon. Open **Settings…** from that menu.

An alternative ZIP is available. Download it and its own `.zip.sha256` file, verify with
`shasum -a 256 -c PetScape-1.0.0-10-universal.zip.sha256`, extract and drag the app to Applications.
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
checksums were exercised on macOS 27.0.1 / Xcode 27.1. A clean download/install/first-launch
Gatekeeper flow has **not** been tested. Managed Macs and older supported OS versions remain
unverified; no warning-free launch or universally available override is promised. The known V8
pixel-QA failure remains disclosed as an owner-approved exception for v1.0.0 only.

## Brazilian Portuguese installation copy

O PetScape v1.0.0 oferece um app **universal para Macs Apple silicon e Intel com macOS 14 ou
posterior**. Não é preciso Xcode, Git, baixar o projeto ou compilar. A execução em hardware Intel
e a instalação limpa no macOS 14–26 ainda não foram verificadas; as duas arquiteturas são
compiladas e têm a assinatura conferida.

1. Na [release oficial](https://github.com/danielcbdev/petscape/releases/tag/v1.0.0), abra **Assets**
   e baixe **PetScape-1.0.0-10-universal.dmg**. Os links **Source code** são para desenvolvimento.
2. Para conferir a integridade, baixe também o arquivo `.dmg.sha256` correspondente para a mesma
   pasta. No Terminal, entre nessa pasta e execute:

   ```bash
   shasum -a 256 -c PetScape-1.0.0-10-universal.dmg.sha256
   ```

   O resultado deve mostrar o nome do DMG e `OK`. Se falhar, não abra o app: confira versão/build,
   baixe os dois arquivos novamente da release oficial e repita. Se persistir, avise o responsável.
3. Abra o DMG. Encerre qualquer cópia do PetScape em execução e arraste **PetScape.app** para o
   atalho **Applications / Aplicativos**. Confirme a substituição ao atualizar. Faça backup das
   preferências e pacotes instalados antes; eles permanecem na sua conta. Não há atualização
   automática nem garantia de migração ao voltar para uma versão anterior.
4. Ejete o disco **PetScape 1.0.0** no Finder e abra **Aplicativos → PetScape**. Procure o **ícone de
   pata na barra de menus**: não há ícone no Dock. Abra **Ajustes…** nesse menu.

Há também um ZIP: baixe-o junto com o seu `.zip.sha256`, execute
`shasum -a 256 -c PetScape-1.0.0-10-universal.zip.sha256`, extraia e arraste o app para Aplicativos.
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
e checksums no macOS 27.0.1 / Xcode 27.1. Download, instalação limpa e primeira abertura com
Gatekeeper **não foram testados**. Outros sistemas e dispositivos gerenciados permanecem não
verificados. A falha histórica V8 está documentada como exceção aprovada pelo proprietário apenas
para a v1.0.0, sem ser apresentada como teste aprovado.
