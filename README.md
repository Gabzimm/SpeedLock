# SpeedLock

App Flutter para controlo e segurança de trotinetes elétricas — BLE (+
USB/Wi-Fi), autenticação com verificação por localização, autorização de
comandos, partilha de acesso entre contas, modo offline, perfil
personalizável e histórico. Os 11 ecrãs estão todos portados a sério; o
mockup navegável original fica em `design/`.

## Arquitetura

- **Firebase Auth** — contas, sessões, login anónimo (modo convidado).
- **Firestore** — dados (dispositivos, pedidos de acesso, perfis, histórico).
- **Firebase Storage** — fotos de perfil.
- **Backend próprio (`server/`)** — um servidor Express normal, feito
  para correr numa VPS (ex: BlazeHosting), com a mesma lógica que antes
  estava em Cloud Functions. Fala com a Firebase Auth/Firestore através
  do Admin SDK (que funciona a partir de qualquer servidor Node, não só
  de Cloud Functions) — só a "compute" mudou de sítio, os dados
  continuam na Firebase.

Isto foi uma decisão explícita: manter Auth/Firestore geridos pela
Firebase (evita reescrever login, verificação por localização, etc.) mas
correr a lógica de decisão num servidor que já controlas, ao lado dos
teus outros bots/sites.

## Estrutura

```
lib/
  main.dart                     - arranque: Firebase, Riverpod, tema, router
  app/
    theme.dart                  - cores/fontes copiadas do mockup HTML
    api_config.dart             - URL do backend próprio
    router.dart                 - rotas dos 11 ecrãs + redirect por sessão
    router_refresh_stream.dart  - liga o stream de auth ao GoRouter
  screens/
    onboarding/                 - abertura, boas_vindas, login, criar_conta, recuperar_senha, ligar
    home/                       - controlo
    account/                    - perfil, dispositivos, historico, configuracoes
    widgets/                    - componentes partilhados + placeholder_screen.dart
  services/
    api_client.dart             - cliente HTTP para o backend proprio (ApiClient/ApiException)
    auth_service.dart           - login, registo, recuperacao de senha, verificacao por localizacao
    device_command_service.dart - pede comandos assinados ao backend antes de agir
    device_service.dart         - listMyDevices, setStolenStatus, listMyHistory
    access_request_service.dart - pedir/aprovar acesso a trotinete de outra conta
    profile_service.dart        - perfil (banner, cor, foto, bio) + Firestore direto para leitura
    ble/protocols/
      scooter_protocol.dart     - interface comum
      xiaomi_protocol.dart      - implementado (placeholders nos bytes exatos)
      ninebot_protocol.dart     - implementado (placeholders + aviso sobre firmware encriptado)
      unmapped_protocols.dart   - stubs das marcas por reverse-engineer (5 prioritarias)
      usb_transport.dart        - transporte USB real, codec de comandos por confirmar
      wifi_transport.dart       - transporte Wi-Fi real, codec de comandos por confirmar
      protocol_registry.dart    - deteccao de marca por nome BLE anunciado
  state/
    auth_provider.dart
    connection_provider.dart    - liga marca/id ao protocolo certo (BLE, ou manual para USB/Wi-Fi)
    device_provider.dart        - estado do ecra Controlo
    profile_provider.dart
    access_request_provider.dart
    device_management_provider.dart

server/                         - backend proprio (Express) - ver "Deploy" e "Arquitetura do backend" abaixo
  package.json
  .env.example
  index.js                      - so liga as pecas (helmet, cors, logger, rotas, error handler) - sem logica propria
  firebaseAdmin.js              - Admin SDK com conta de servico
  config/
    constants.js                - todos os valores ajustaveis (TTLs, limites, chaves), num so sitio
    logger.js                   - logger estruturado (pino)
  lib/
    httpError.js                - erros com os mesmos `code` que existiam nas Cloud Functions
    crypto.js                   - geracao de codigo, hash, assinatura de comandos
    cache.js                    - cache TTL em memoria (evita pedidos repetidos a Firebase Auth)
  middleware/
    auth.js                     - verifica o token da Firebase, define req.auth, isGuest()
    adminAuth.js                - protege /admin com password (HTTP Basic Auth)
    validate.js                 - liga um schema (validation/) a uma rota
    rateLimiters.js             - limites de pedidos em memoria (login, registo, reset, comandos, admin)
    requestLogger.js            - uma linha de log por pedido
    errorHandler.js             - middleware de erro final
  admin-public/                 - paginas do painel (logs + utilizadores), servidas so depois do adminAuth
  validation/                   - schemas zod: o que cada rota aceita no corpo do pedido
  repositories/                 - acesso puro ao Firestore/Firebase Auth, sem regras de negocio
  services/                     - logica de negocio (authService, deviceService, commandService, etc.)
  routes/                       - finas: validacao + limite + chamada ao service
    auth.js       - registerUser, checkLoginLocation, confirmLoginVerification, password reset, finalizeGuestRegistration
    devices.js    - registerDevice, listMyDevices, setStolenStatus, pedidos de acesso
    profile.js    - updateProfile, getDeviceMembersProfiles
    commands.js   - requestDeviceCommand (autorizacao), issueOfflineSpeedLimitToken
    history.js    - listMyHistory
    admin.js      - GET /admin (painel), GET /admin/api/logs, GET /admin/api/users, GET /admin/api/users/:uid

firestore.rules                 - cada um so le o seu proprio users/{uid}
storage.rules                   - avatars/{uid}.jpg - so o proprio escreve
design/                         - mockup HTML original + previews
```

## Antes de correr a app

1. `flutter pub get`
2. `flutterfire configure` (gera `lib/firebase_options.dart` — depois descomentar a linha em `main.dart`). Continua a ser necessário mesmo com o backend próprio, porque a app fala diretamente com a Firebase Auth e o Firestore (perfil).
3. Editar `lib/app/api_config.dart` com o domínio real do teu backend assim que estiver no ar.
4. **Este projeto ainda não tem `android/` nem `ios/`** — só o código Dart. Correr `flutter create .` nesta pasta para gerar essa estrutura nativa, e só depois acrescentar as permissões antes de testar o ecrã Ligar num aparelho real:
   - **Android** (`AndroidManifest.xml`): `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`, `INTERNET`.
   - **iOS** (`Info.plist`): `NSBluetoothAlwaysUsageDescription`.

## Deploy do backend na BlazeHosting (ou qualquer VPS Linux)

Isto assume o mesmo fluxo que já usas para os teus bots/sites: geridos pelo teu `main.py` (um processo Node, como o `Site-loja`), não PM2.

1. **Gerar a chave de conta de serviço da Firebase** — Firebase Console → Definições do projeto → Contas de serviço → "Gerar nova chave privada". Isto dá um `.json`; o Admin SDK precisa dele porque, fora das Cloud Functions, não há credenciais automáticas.
2. **Copiar o ficheiro para a VPS**, fora da pasta do projeto e com permissões restritas: `scp service-account.json usuario@teu-ip:/caminho/service-account.json` e depois `chmod 600` nesse ficheiro na VPS.
3. **Copiar a pasta `server/`** para a VPS, ao lado dos teus outros bots/sites (ex: `Speedlock-backend/`).
4. **Configurar:** copiar `.env.example` para `.env` (dentro da pasta, ao lado do `index.js`) e preencher `GOOGLE_APPLICATION_CREDENTIALS`, `SMTP_*`, `COMMAND_SIGNING_KEY`, `OFFLINE_SIGNING_KEY`. Gerar as chaves de assinatura com `openssl rand -hex 32` — nunca usar os valores de desenvolvimento que vêm como fallback no código. O `npm install` (incluindo dependências novas como `zod`, `helmet`, `pino`) corre sozinho da primeira vez que o `main.py` arrancar este processo, tal como já faz para o `Site-loja`.
5. **Acrescentar ao `main.py`** uma entrada com `runner: 'node'`, tal como as outras (ver README do gestor de bots).
6. **Nginx como proxy reverso**, para teres HTTPS num domínio em vez de expor a porta diretamente — configuração mínima de bloco `server` a apontar `proxy_pass` para `http://localhost:3000` (ou a porta que puseres no `.env`), com os cabeçalhos `Host`, `X-Real-IP` e `X-Forwarded-For` reencaminhados (é o `X-Forwarded-For` que a verificação de localização do login e os limitadores de pedidos usam para saber o IP real).
7. **HTTPS com certbot** (obrigatório — a app envia tokens de sessão no cabeçalho, isso nunca deve andar sem TLS): `certbot --nginx -d api.speedlock.app`.
8. Atualizar `lib/app/api_config.dart` com o domínio real e voltar a compilar a app.

`GET /health` responde `{"ok": true}` sem precisar de sessão — útil para confirmar que o deploy está de pé antes de testares a app.

## Arquitetura do backend (routes → services → repositories)

O `server/` está organizado em camadas, cada uma só com uma responsabilidade:

- **`routes/`** — só liga validação (`validation/`), limite de pedidos (`middleware/rateLimiters.js`) e o serviço certo. Não tem nenhuma regra de negócio.
- **`services/`** — toda a lógica: quem pode fazer o quê, o que acontece a seguir. `commandService.js` é o mais sensível — nenhum comando chega à trotinete sem passar por aqui.
- **`repositories/`** — só acesso a dados (Firestore, Firebase Auth). Nenhuma decisão é tomada aqui, só "ler isto" / "escrever aquilo".
- **`validation/`** — schemas `zod`: o que cada rota aceita no corpo do pedido, num só sítio por grupo de rotas.
- **`config/constants.js`** — todos os valores ajustáveis (TTLs, limites, chaves de nível de acesso), sem nenhuma função misturada.

**Preparado para tráfego:** os limites de tentativas (login, registo, recuperação de senha, comandos) passaram de leituras/escritas no Firestore por pedido para `express-rate-limit` em memória — mais rápido e sem condição de corrida. Pedidos a `admin.auth().getUser()` (nomes de utilizadores no histórico, pedidos de acesso) passam por uma cache com TTL (`lib/cache.js`) em vez de repetir o mesmo pedido à Firebase várias vezes no mesmo ecrã.

**Aviso sobre o rate limiting em memória:** os limites contam à parte em cada processo Node. Enquanto isto correr como um só processo (o que o `main.py` já faz), os limites são exatos. Se um dia isto passar a correr em vários processos ao mesmo tempo (para aguentar mais tráfego), cada processo conta por si — na prática o limite real passa a ser (limite configurado × número de processos). Nessa altura, trocar o "store" do `express-rate-limit` para um Redis partilhado resolve isso sem mexer em mais nada.

**Observabilidade:** os logs saem estruturados em JSON (`pino`, `config/logger.js`) — uma linha por pedido com método, caminho, status, duração e `uid` quando há sessão, e uma linha extra com o erro completo sempre que algo falha de forma inesperada (nunca em texto livre, para conseguires filtrar/pesquisar). Saem para dois sítios ao mesmo tempo: a consola (o que já vês através do `main.py`) e ficheiro, em `server/logs/` — roda automaticamente todos os dias (ou se um dia passar de 20MB) e apaga sozinho ficheiros com mais de 30 dias, para nunca encheres o disco sem reparares. `LOG_LEVEL` no `.env` controla o detalhe. O campo `level` sai como número (30=info, 40=warn, 50=error) — é uma limitação real do `pino` combinado com múltiplos destinos, documentada no topo do `config/logger.js`.

**Painel de logs (`/admin`):** em vez de leres os logs na consola do `main.py` (visível a quem lá tiver acesso), há uma página protegida por password em `https://o-teu-dominio/admin` — pede utilizador/senha do browser (HTTP Basic Auth), mostra as entradas do dia com atualização automática a cada 5 segundos, filtro por nível, e seletor de data para dias anteriores. Só funciona com `ADMIN_USER`/`ADMIN_PASSWORD` preenchidos no `.env` — sem isso, fica bloqueado de propósito (erro 500) em vez de aberto sem password. Isto não tem nada a ver com contas de utilizador da app; é só para ti. Como é HTTP Basic Auth, só é seguro sobre HTTPS — já tens isso, via o certbot do passo de deploy.

**Painel de utilizadores (`/admin/users.html`):** lista todas as contas (email, nome, quando foram criadas, último login), com uma caixa de pesquisa por email ou nome. Ao selecionares uma conta, mostra os dispositivos que tem (com o nível de acesso e se está reportada como roubada) e a atividade recente — reaproveitando os mesmos serviços que a app usa (`deviceService`, `historyService`), só que a ver qualquer conta em vez de só a tua. A pesquisa percorre a Firebase Auth página a página (não há pesquisa por texto nativa) até um limite de segurança de 5000 contas percorridas — para uma escala muito maior do que isso, precisarias de um índice de pesquisa dedicado (`services/userAdminService.js` documenta isto).

**Segurança:** cabeçalhos HTTP protegidos por `helmet`, corpo do pedido limitado a 100kb (evita pedidos gigantes ocuparem memória antes de qualquer validação correr), e o `requestPasswordReset` ganhou um limite de tentativas que não existia antes (qualquer um conseguia pedir emails de recuperação sem limite nenhum).


### Porque é que só a Firestore/Storage/Auth continuam na Firebase

Reescrever autenticação (hashing de password, tokens, sessões) e a
verificação por localização do zero seria dias de trabalho a refazer
algo que já funciona bem e é grátis até um volume razoável. Mover só a
"compute" (as regras de negócio) foi a troca que aproveita a infra que
já tens (BlazeHosting) sem deitar fora o que já estava certo.

## Ecrã Ligar → registo de posse + pedido de acesso

Ao tocar numa trotinete encontrada por BLE: liga (`protocol.connect`) e,
se a conta não for convidada, chama `/registerDevice`, que implementa
"primeiro a ligar é o dono". Se a trotinete já pertencer a outra conta,
oferece "Pedir acesso" (`/requestDeviceAccess`) em vez de simplesmente
falhar — o dono vê o pedido no ecrã Dispositivos e aprova com um nível,
ou recusa.

USB (temporariamente indisponível, ver abaixo) e Wi-Fi têm categorias
próprias no mesmo ecrã, com ligação real (socket aberto de verdade, no
caso do Wi-Fi) — ver "Transportes USB e Wi-Fi" abaixo para o que ainda
falta.

## Perfil personalizável + visibilidade partilhada

`updateProfile` e `getDeviceMembersProfiles` sustentam o ecrã Perfil
(banner, cor de destaque, foto via Firebase Storage, bio) e a faixa no
Controlo que mostra o dono de uma trotinete partilhada — o efeito
"ligo-me à trotinete do João e vejo o perfil dele" só acontece depois de
ele aprovar o pedido de acesso.

## Regras de segurança (Firestore + Storage)

- **`firestore.rules`** — o ecrã Perfil lê o próprio documento diretamente do Firestore (`watchOwnProfileDoc`), não via o backend. Sem regras, o Firestore recusa tudo por omissão; a regra aqui só deixa cada um ler o seu próprio `users/{uid}`, nunca escrever (isso continua só via `/updateProfile`).
- **`storage.rules`** — o upload de foto só pode escrever no próprio ficheiro (`avatars/{uid}.jpg`), com limite de 5MB e a exigir que seja mesmo uma imagem. A leitura é pública de propósito (é assim que a foto aparece a quem partilha a trotinete).

Fazer deploy com `firebase deploy --only firestore:rules,storage` (isto
continua a passar pela Firebase CLI — as regras são só para
Firestore/Storage, não para o backend).

## Ecrã Histórico

`logHistory` (helper interno) grava uma entrada sempre que uma ação
real é autorizada: registar trotinete, bloquear/desbloquear, mudar
limite, luzes, buzina, conceder acesso, reportar como roubada. Nunca
regista tentativas suspeitas (essas são recusadas com erro antes de lá
chegar) — isso fica só em `suspiciousActivity`, de propósito.
`/listMyHistory` junta as últimas entradas de todas as trotinetes
próprias/partilhadas, já com o nome de quem fez cada ação.

## Ecrãs Dispositivos + Configurações

- **Dispositivos** — lista trotinetes próprias/partilhadas (`/listMyDevices`) e mostra os pedidos de acesso pendentes (`/listIncomingAccessRequests`) com aprovar/recusar direto no ecrã.
- **Configurações** — "Reportar como roubada" (`/setStolenStatus`) aplica-se à trotinete ligada; "Esquecer este dispositivo" usa `AuthService.forgetThisDevice`. Termos/Privacidade ficam marcados como "por publicar", já que o site ainda não existe.

## Ecrã Controlo

Cada ação (limite de velocidade, modo, bloquear, luzes, buzina) passa
pelo `DeviceNotifier`, que pede autorização ao backend antes de tocar no
BLE — nada contorna essa camada. O gauge circular (`speed_gauge.dart`) é
um `CustomPainter` que reproduz a matemática do SVG do mockup (raio 92,
escala 0–25 km/h).

Duas coisas que não vêm de telemetria real (nenhum protocolo ainda
expõe isso) — deixadas como estimativa visível, não escondida: a
autonomia é `bateria% × 20 km` (cálculo arbitrário), e o card "Marca"
mostra a marca detetada, não um modelo específico.

## Comandos ao dispositivo — camada de autorização

`device_command_service.dart` pede ao backend um comando assinado antes
de qualquer ação no Controlo. `/requestDeviceCommand` valida dono/nível
de acesso e nonce (anti-replay); se algo parecer adulterado, recusa com
um erro genérico (nunca diz o motivo exato), regista em
`suspiciousActivity` e, ao fim de 3 tentativas suspeitas, marca a conta
como sinalizada (passa a recusar sempre).

**Nota de uma revisão anterior:** a primeira versão disto devolvia, para
pedidos suspeitos, uma resposta "de sucesso" com assinatura falsa em vez
de erro — a ideia era iludir um atacante. O problema: a app nunca
verifica a assinatura, só olha para "correu sem erro?" antes de mandar
bytes reais por BLE — por isso essa resposta "falsa" tinha, na prática,
o mesmo efeito de uma aprovação real. Corrigido para recusar com erro
de verdade; `setSpeedLimitOfflineAware` (modo offline) foi ajustado para
nunca contornar essa recusa com a cache offline (só cai para offline
quando o pedido nem chega a ser respondido, nunca numa recusa explícita).

## Autenticação e verificação por localização

`auth_service.dart` implementa "servidor decide, app só pede": o cliente
confirma a password na Firebase Auth e depois pergunta ao backend se
aquela localização já é confiada. A app nunca envia a sua própria
localização — o servidor lê o IP real do pedido (via `geoip-lite`) e
compara com as localizações já confiadas no Firestore.

Limites ajustáveis em `server/config/constants.js`: `CODE_TTL_MINUTES`,
`MAX_LOGIN_ATTEMPTS_PER_HOUR`, `TRUSTED_DEVICE_DAYS`.

## Estado de cada marca

| Marca | Estado | Nota |
|---|---|---|
| Xiaomi | Implementado (placeholder) | Melhor documentação pública disponível |
| Ninebot | Implementado (placeholder) | Firmware novo usa encriptação partilhada com a Xiaomi ("miauth") — não implementado, precisa de token de conta |
| Kukirin, Havee, YUME, Halo Knight, NAVEE | Stub — prioritário | App oficial confirmada; várias parecem partilhar o mesmo hardware OEM "DanDan" — sniffar uma primeiro (Kukirin é a mais fácil de arranjar em segunda mão) pode resolver as outras de uma vez. |
| NIU | Stub | Arquitetura diferente: depende mais de API de nuvem do que comando BLE direto |
| Dualtron, ENGWE, iScooter, Apollo, Hiboy, Pure Electric | Stub | App oficial confirmada, protocolo não documentado publicamente |

Nenhum UUID ou byte de comando aqui é verificado. Antes de testar em
hardware real, confirmar contra protocolo capturado (sniff BLE) ou
documentação da comunidade.

## Transportes USB e Wi-Fi

**USB está temporariamente desativado.** O pacote `usb_serial` que abria
a porta a sério ficou desatualizado — a sua configuração Android chama
`jcenter()`, um repositório que já não existe, e isso quebra a
compilação com ferramentas Android atuais (erro real visto num build:
"Could not find method jcenter()"). `usb_transport.dart` mantém a mesma
interface (`UsbDevice`, `UsbTransport`, `UsbScooterProtocol`) mas sem a
dependência — `listDevices()` devolve sempre uma lista vazia, e ligar
falha com uma mensagem clara. O separador USB continua visível no ecrã
Ligar, só não encontra nada. Para reativar: trocar o conteúdo desse
ficheiro por uma biblioteca USB-série mantida e compatível com AGP
atual, sem precisar de mexer no resto da app.

`wifi_transport.dart` implementa ligação Wi-Fi real — abre mesmo o
socket. O que continua por confirmar, tal como no BLE, é o codec de
comandos de qualquer marca — isso exige o mesmo trabalho de engenharia
reversa com hardware real. Ligar por Wi-Fi funciona (mostra "ligado"),
mas qualquer comando falha com um erro claro em vez de mandar bytes
inventados para a trotinete.

Nota honesta: nenhuma marca da lista está confirmada a usar Wi-Fi para
controlo — todas usam BLE. O transporte Wi-Fi existe sobretudo para
compatibilidade futura com controladores DIY (ESP32/ESP8266), daí o
valor por omissão `192.168.4.1`.

`manualProtocolProvider` liga USB/Wi-Fi ao resto da app sem precisar de
um `BrandEntry` (não há deteção de marca por nome nesses casos). Hoje o
registo de posse (`/registerDevice`) só acontece no caminho BLE — ligar
por USB/Wi-Fi ainda não regista dono.

## Modo offline (só limite de velocidade)

1. Sempre que uma mudança de limite é autorizada online, a app pede em segundo plano (`/issueOfflineSpeedLimitToken`) uma autorização válida por 7 dias, assinada com uma chave diferente da dos comandos em tempo real (`OFFLINE_TOKEN_VALID_DAYS`/`OFFLINE_SIGNING_KEY` em `server/config/constants.js`).
2. Guardada no telemóvel (`flutter_secure_storage`).
3. Se `/requestDeviceCommand` falhar por falta de rede, a app usa essa autorização em cache — só se ainda não tiver expirado, e nunca se a falha for uma recusa explícita do backend.
4. Passados 7 dias sem internet, expira e volta a exigir ligação.

Só cobre `setSpeedLimit`: mesmo com o telemóvel roubado e sessão aberta,
o pior que dá para fazer offline é mudar um limite de velocidade da
própria trotinete já registada.

## Modo "Continuar sem login"

Ao confirmar o aviso, a app abre uma sessão anónima da Firebase — dá ao
convidado um uid válido sem criar conta. `/requestDeviceCommand` deteta
contas anónimas e só deixa passar `setSpeedLimit`; qualquer outro
comando recebe a mesma recusa genérica usada contra tentativas
suspeitas. Se o convidado criar conta a seguir, `AuthService.register`
usa `linkWithCredential` em vez de `/registerUser` — mantém o mesmo uid,
preservando a sessão/estado da app (não há "posse" para transferir,
porque um convidado nunca a teve).

## Sobre atualizações remotas (importante)

A Google Play e a Apple proíbem uma app atualizar-se ou substituir o seu
próprio código por fora do mecanismo oficial da loja. O que é seguro: o
próprio backend já serve dados dinâmicos — se quiseres que a lista de
marcas mude sem nova versão publicada, dá para adicionar uma rota
`/supportedBrands` que o `protocol_registry.dart` consulta em vez de
usar a lista fixa. A lógica de cada protocolo (código Dart) continua a
exigir uma atualização real via loja.

## Sobre distribuição no iPhone

Não existe equivalente direto ao `.apk` no iOS "normal". Opções reais:
TestFlight (até 10.000 testadores por link, primeira versão com revisão
leve da Apple); loja alternativa na UE (ex: AltStore, possível graças ao
DMA, mas exige notarização da Apple e pode ter custos); distribuição
direta pelo site só é permitida pela Apple com 1M+ instalações no ano
anterior — não aplicável a uma app nova.
