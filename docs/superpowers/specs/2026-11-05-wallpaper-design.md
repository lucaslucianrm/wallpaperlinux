# Rolimnet Wallpaper: desenho final

Revisado conforme orientação do usuário: **um único `.sh`, poucas dependências e
apenas aplicar o wallpaper, sem bloquear configurações ou configurar bloqueadores**.

`install.sh` contém instalador, download, adaptadores e comandos operacionais. Copia
a si mesmo para o diretório de dados do usuário; não requer nenhum outro arquivo do
repositório. Requer Bash 4.3+, curl, systemd, util-linux/coreutils e a ferramenta nativa
do desktop. Sem Python, Node, Git, sudo ou dependências baixadas automaticamente.

Timer por usuário a cada hora cheia, persistente. Autostart captura a sessão atual e
reaplica cache recente ou baixa novamente. Não habilita linger nem altera serviços de sistema.

Adaptadores: GNOME, Cinnamon, MATE, Plasma 5/6, Xfce e LXDE/LXQt nos perfis padrão.
Somente o fundo é aplicado; não muda screensaver, autenticação, políticas dconf ou
tela de login. Plasma seleciona o plugin padrão de imagem para exibir o arquivo.
Bloqueio acompanha apenas quando o próprio desktop faz isso.

HTTPS obrigatório, timeout/retries limitados, 25 MiB, PNG/JPEG/WebP com validação básica
de assinatura e marcadores/tamanho. Arquivos temporários, nomes por SHA-256, duas imagens
mantidas e flock evitam perda de fundo e concorrência. Configuração de sessão como pares
NUL, sem executar dados. Desinstalação mantém as imagens para preservar o fundo atual.

Testes Bash executam o arquivo inteiro em diretórios XDG temporários, com comandos
externos controlados e Python indisponível. Verificadores reais checam units/autostart.
Download real testado separadamente sem aplicar wallpaper. Compatibilidade visual ainda
exige VMs reais. Não instalar tarefas nesta máquina durante o desenvolvimento.
