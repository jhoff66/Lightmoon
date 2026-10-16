# Moonlight

App de barra de menus para macOS que ajusta o brilho e a temperatura de cor de monitores externos por software.

Serve para monitores que não aceitam controle por DDC/CI, o que é comum quando o vídeo passa por um hub ou adaptador USB-C para HDMI que descarta esses comandos.

## O que faz

- Brilho, temperatura de cor e contraste por tela, ou em todas de uma vez
- Tela do próprio Mac incluída, com brilho de hardware
- Troca de resolução e taxa de atualização
- Presets com transição suave: Dia, Foco, Noite e Cinema
- Noite automática por horário
- Pausa para os olhos: a cada 20 minutos escurece as telas por 20 segundos
- Atalhos globais: ⌃⌥⇧ + ↑ ↓ para brilho e ← → para temperatura, na tela onde o cursor está
- Apagar as telas, pausar os ajustes e iniciar no login
- Valores salvos por tela e reaplicados ao acordar o Mac ou reconectar

## Como funciona

Nos monitores externos, o Moonlight não conversa com o monitor. Ele guarda a tabela de cores original de cada tela (`CGGetDisplayTransferByTable`) e aplica uma versão modificada pelos ajustes (`CGSetDisplayTransferByTable`). Ao sair, a tabela original é restaurada. Na tela embutida, o brilho usa o controle de hardware do próprio macOS.

Consequências desse método:

- Nos externos, o brilho só diminui a partir do que está ajustado no próprio monitor, com piso de 10%.
- Volume, troca de entrada e modo de imagem não são possíveis, porque dependem de DDC/CI.
- Outros apps que mexem na tabela de cores (como o MonitorControl) entram em conflito se rodarem junto.

## Instalar

Cole no Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/jhoff66/Moonlight/main/install.sh | bash
```

O script baixa a versão mais recente, copia para Applications e abre o app.

### Pelo DMG

Baixe o `Moonlight.dmg` na página de [releases](../../releases) e arraste o app para Applications.

O app não é notarizado pela Apple, então o macOS barra a primeira abertura de um DMG baixado pelo navegador, às vezes dizendo que o app "está danificado". Ele não está. Para liberar, cole no Terminal:

```sh
xattr -cr /Applications/Moonlight.app
```

Requer macOS 14 ou mais recente. Roda em Apple Silicon e em Intel.

## Compilar

Precisa só das Command Line Tools da Apple (`xcode-select --install`).

```sh
./build.sh           # gera o Moonlight.app
./build.sh install   # também copia para /Applications e reabre
./build.sh dmg       # também gera o Moonlight.dmg
```

## Licença

MIT. Veja [LICENSE](LICENSE).
