# Rolimnet Wallpaper para Linux

**Basta baixar e executar o arquivo `install.sh`.** Ele contém o instalador e o
programa que continuará executando. Não precisa de Python, Git, Node ou bibliotecas externas.

Baixa a imagem de **https://core.rolimnet.com/api/wallpaper/image**, aplica o wallpaper
imediatamente e cria uma tarefa de atualização **a cada 1 hora**.

Não cria políticas ou bloqueios de configuração. Você continua livre para trocar o
papel de parede manualmente; a próxima atualização agendada reaplicará a imagem da URL.
Não modifica senha, bloqueador de tela, temas do sistema ou tempo de inatividade.

## AppImage com o ícone Windows

O pacote `Rolimnet-Wallpaper-x86_64.AppImage` inclui o ícone original do Windows,
o iniciador e o instalador existente. O AppImage é específico de arquitetura;
os arquivos Bash originais continuam disponíveis.

```bash
chmod +x Rolimnet-Wallpaper-x86_64.AppImage
./Rolimnet-Wallpaper-x86_64.AppImage
```

Sem FUSE, use `./Rolimnet-Wallpaper-x86_64.AppImage --appimage-extract-and-run`.

Execute como usuário da sessão gráfica, sem sudo. O instalador mantém o timer
de uma hora e instala uma cópia persistente do agente. O AppImage pode ser removido
após instalar. É necessário systemd de usuário e um dos desktops já suportados;
o pacote não substitui as ferramentas de configuração do desktop.

Para gerar o pacote, obtenha o [appimagetool oficial](https://github.com/AppImage/appimagetool/releases)
e execute na pasta do projeto:

```bash
APPIMAGETOOL=/caminho/appimagetool-x86_64.AppImage bash build_appimage.sh
```

O empacotador baixa seu runtime se necessário. Para usar um runtime já baixado,
defina `APPIMAGETOOL_RUNTIME_FILE=/caminho/runtime-x86_64`. O ícone é incluído
no arquivo; sua miniatura no gerenciador de arquivos depende da integração
AppImage do desktop. Não cria integração global nem altera políticas do Polkit.

## Instalação

Baixe o arquivo `rolimnet-wallpaper`, abra um terminal na pasta do arquivo e execute:

```bash
chmod +x rolimnet-wallpaper
./rolimnet-wallpaper
```

Esse é o mesmo programa de `install.sh`, com nome sem extensão e permissão de
execução. É um executável Bash, não um binário compilado: mantém os requisitos
abaixo e pode ser usado em diferentes arquiteturas com essas ferramentas instaladas.
Use `./rolimnet-wallpaper status`, `update` ou `uninstall` para os demais comandos.

Para gerar novamente o arquivo de distribuição após alterar `install.sh`:

```bash
cp install.sh rolimnet-wallpaper
chmod +x rolimnet-wallpaper
```

Baixe somente `install.sh` pelo GitHub, abra um terminal na pasta do arquivo e execute:

```bash
bash install.sh
```

Execute como o usuário da sessão gráfica, **sem sudo**. O arquivo copia a si mesmo
para o diretório de dados do usuário e configura a tarefa. Pode apagar o arquivo
baixado depois da instalação. Executar novamente atualiza a instalação, sem duplicar tarefas.

Evite executar o conteúdo por pipe (`curl ... | bash`): o instalador precisa de um
arquivo local para fazer essa cópia. Não precisa baixar o restante do repositório.

## Requisitos

- Linux com **Bash 4.3+**, curl com HTTPS e **systemd de usuário funcionando**.
- Ferramentas comuns do Linux: `flock` (util-linux), `sha256sum`, `od`, `mktemp`,
  `date` e demais comandos do coreutils.
- O comando nativo do seu ambiente gráfico, conforme a tabela abaixo.

Normalmente tudo já existe em uma instalação desktop. O script verifica as ferramentas
principais e recusa a instalação quando falta algo; não instala pacotes automaticamente.
Se faltar curl, por exemplo, instale-o pelo gerenciador da sua distribuição.

## Ambientes atendidos

| Ambiente | Como aplica o wallpaper |
|---|---|
| Cinnamon / Linux Mint Cinnamon | `gsettings`, imagem do desktop |
| GNOME / Ubuntu / Fedora Workstation | `gsettings`, variantes clara e escura quando disponíveis |
| KDE Plasma 5/6 / Kubuntu | `qdbus6`, `qdbus` ou `qdbus-qt5`, script nativo do Plasma para os desktops/monitores existentes |
| MATE / Ubuntu MATE | `gsettings`, imagem do desktop MATE |
| Xfce / Xubuntu | `xfconf-query`, imagens dos monitores e workspaces já configurados |
| LXDE | `pcmanfm`, perfil padrão da sessão LXDE |
| LXQt / Lubuntu | `pcmanfm-qt`, perfil padrão `lxqt` |

As ferramentas normalmente vêm com o próprio desktop. Para Plasma, pode ser necessário
instalar a ferramenta Qt D-Bus correspondente à distribuição e à versão do Qt.

Os adaptadores têm testes automatizados com os comandos gráficos simulados. **A
validação visual nas versões reais de cada ambiente ainda precisa ser feita**, em
X11 e Wayland. No Xfce, novos monitores/workspaces devem ter suas configurações de
fundo criadas pelo desktop antes da atualização. Perfis personalizados do PCManFM
precisam de adaptação.

### Tela de bloqueio

Este script configura **somente o papel de parede**. Onde o bloqueador nativo acompanha
o fundo do desktop, como normalmente acontece no Cinnamon e GNOME, a imagem também
aparece no bloqueio, possivelmente desfocada pelo sistema. Nos demais casos, o bloqueio
mantém suas próprias configurações. Não altera a tela de login do GDM, SDDM ou LightDM.

Se um slideshow, extensão ou outro gerenciador de wallpaper estiver ativo, ele poderá
trocar a imagem novamente. O script respeita essas configurações.
No Plasma, seleciona o plugin padrão de imagem para aplicar o arquivo. O usuário pode
escolher outro plugin novamente pelas configurações; nenhuma opção é bloqueada.

## Funcionamento do agendamento

- Primeira aplicação imediata ao instalar.
- Depois, **a cada hora cheia**, todos os dias (08:00, 09:00, 10:00 etc.).
- São horários fixos, não uma hora contada desde a instalação.
- Timer systemd com `Persistent=true`: recupera execução perdida quando o gerenciador
  do usuário volta a funcionar após o computador ficar desligado.
- Não acorda o computador nem habilita linger. A sessão gráfica precisa estar acessível
  para aplicar o fundo; sem ela, a execução pode falhar e tentar novamente no próximo login.
- Autostart registra o ambiente do login atual. Reaplica a imagem armazenada se ela
  tem menos de 1 hora; caso contrário faz novo download.
- Não depende de manter um terminal aberto.

Para aplicar o novo agendamento em uma instalação existente, execute novamente
`./rolimnet-wallpaper` (ou `bash install.sh`) com o arquivo atualizado, sem sudo.

Se a primeira aplicação falhar depois da criação da tarefa, o timer permanece ativo.
Corrija a causa e execute `update` para tentar novamente.

## Atualizar, consultar e desinstalar

Se ainda tiver o arquivo baixado:

```bash
bash install.sh update
bash install.sh status
bash install.sh uninstall
```

Ou use a cópia instalada:

```bash
wallpaper_script="${XDG_DATA_HOME:-$HOME/.local/share}/rolimnet-wallpaper/rolimnet-wallpaper.sh"
bash "$wallpaper_script" update
bash "$wallpaper_script" status
bash "$wallpaper_script" session    # recaptura a sessão gráfica atual
bash "$wallpaper_script" uninstall
```

Timer e logs:

```bash
systemctl --user list-timers --all rolimnet-wallpaper.timer
journalctl --user -u rolimnet-wallpaper.service --since yesterday
```

A desinstalação remove o timer, autostart, programa e configuração. Mantém os arquivos
das imagens e o wallpaper atual; não restaura o fundo anterior à instalação. Depois
de escolher outro fundo pelas configurações do desktop, pode apagar as imagens mantidas.

## Downloads e falhas

- HTTPS com verificação de certificado; redirecionamentos também precisam usar HTTPS.
- Timeout de conexão de 15 segundos e de transferência de 60 segundos, com até duas
  novas tentativas para falhas transitórias.
- Até 25 MiB. Versões antigas do curl podem limitar o download apenas quando o servidor
  informa Content-Length; o tamanho também é conferido ao final.
- PNG, JPEG e WebP: verificação básica de assinatura e marcadores/tamanho do arquivo.
  Isso identifica HTML e vários truncamentos, mas não substitui um decodificador de imagem.
- Download temporário e substituição atômica. Falha de rede ou validação preserva o fundo anterior.
- Nome por SHA-256 para o desktop reconhecer imagens novas. Guarda a imagem atual e a anterior.
- Uma atualização por vez, inclusive chamadas manuais e agendadas.
- Só registra sucesso após os comandos de aplicação terminarem. Uma falha entre os
  comandos de monitores/variantes pode deixar uma aplicação parcial; a execução seguinte tenta novamente.
- Ambiente da sessão armazenado como dados, sem `source` ou `eval`. Arquivos privados do usuário.

## Arquivos criados automaticamente

O usuário distribui apenas `install.sh`; o próprio script gera estes arquivos:

```text
~/.local/share/rolimnet-wallpaper/rolimnet-wallpaper.sh
~/.local/share/rolimnet-wallpaper/wallpaper-<sha256>.png  # ou .jpg/.webp
~/.config/rolimnet-wallpaper/desktop
~/.config/rolimnet-wallpaper/session.env
~/.config/systemd/user/rolimnet-wallpaper.service
~/.config/systemd/user/rolimnet-wallpaper.timer
~/.config/autostart/rolimnet-wallpaper.desktop
~/.local/state/rolimnet-wallpaper/image
~/.local/state/rolimnet-wallpaper/last-success
~/.local/state/rolimnet-wallpaper/update.lock
```

Respeita `XDG_CONFIG_HOME`, `XDG_DATA_HOME` e `XDG_STATE_HOME`.

## Para ampliar a compatibilidade

| Cenário | O que falta |
|---|---|
| Sway / wlroots | Adaptador para swaymsg, swaybg ou swww, conforme quem gerencia o fundo |
| Hyprland | Integração com hyprpaper/swww usado pela sessão |
| COSMIC, Budgie e outros desktops | Verificar suas APIs e adicionar adaptadores próprios |
| LXQt em Wayland com perfil/compositor personalizado | Detectar o perfil efetivo e o gerenciador de wallpaper |
| Distribuições sem systemd, como algumas edições de Void, Alpine e Devuan | Agendador alternativo e integração com a sessão gráfica |
| Garantia de suporte por versão | Testes em VMs/máquinas reais: instalação, login, suspensão, rede offline, múltiplos monitores e remoção |

Adicionar um desktop não significa que todo bloqueador dele acompanhará o wallpaper.
O programa continuará sem travar configurações nem forçar alterações em bloqueadores.

## Testes e GitHub

```bash
bash -n install.sh tests/test.sh
bash tests/test.sh
```

Os testes executam instalação, atualização e remoção em diretórios XDG temporários,
com ferramentas gráficas/systemd simulados e Python deliberadamente indisponível.
Não mudam o wallpaper nem instalam tarefas reais na máquina dos testes. Quando presentes,
os verificadores reais do systemd e Desktop Entry validam os arquivos gerados.

Publique o conteúdo desta pasta como raiz do repositório para o GitHub reconhecer
`.github/workflows/tests.yml`. Os outros arquivos são documentação e testes; para
instalar, o usuário precisa somente de `install.sh`.

Referências: [timers systemd](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html),
[scripting do Plasma](https://develop.kde.org/docs/plasma/scripting/api/),
[Cinnamon Screensaver](https://github.com/linuxmint/cinnamon-screensaver/blob/master/README.md),
[perfis do PCManFM-Qt](https://github.com/lxqt/pcmanfm-qt/wiki).
