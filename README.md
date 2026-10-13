# Lightmoon

App de barra de menus para macOS que ajusta o brilho e a temperatura de cor de monitores externos por software.

Serve para monitores que não aceitam controle por DDC/CI, o que é comum quando o vídeo passa por um hub ou adaptador USB-C para HDMI que descarta esses comandos.

## O que faz

- Brilho e temperatura de cor por monitor externo
- Presets com transição suave: Dia, Foco, Noite e Cinema
- Ajuste conjunto de todos os monitores
- Pausa sem perder os valores
- Início automático no login
- Valores salvos por monitor e reaplicados ao acordar o Mac ou reconectar a tela

## Como funciona

O Lightmoon não conversa com o monitor. Ele guarda a tabela de cores original de cada tela (`CGGetDisplayTransferByTable`) e aplica uma versão multiplicada pelos ajustes (`CGSetDisplayTransferByTable`). Ao sair, a tabela original é restaurada.

Consequências desse método:

- O brilho só diminui a partir do que está ajustado no próprio monitor, com piso de 10%.
- Volume, troca de entrada e modo de imagem não são possíveis, porque dependem de DDC/CI.
- Outros apps que mexem na tabela de cores (como o MonitorControl) entram em conflito se rodarem junto.

## Instalar

Baixe o `Lightmoon.dmg` na página de [releases](../../releases) e arraste o app para Applications.

O app não é notarizado pela Apple. Na primeira abertura o macOS bloqueia; libere em Ajustes do Sistema → Privacidade e Segurança → "Abrir Mesmo Assim".

Requer macOS 14 ou mais recente. Roda em Apple Silicon e em Intel.

## Compilar

Precisa só das Command Line Tools da Apple (`xcode-select --install`).

```sh
./build.sh           # gera o Lightmoon.app
./build.sh install   # também copia para /Applications e reabre
./build.sh dmg       # também gera o Lightmoon.dmg
```

## Licença

MIT. Veja [LICENSE](LICENSE).
