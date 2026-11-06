# Wallpaper Linux Implementation Plan

> **For agentic workers:** Executado nesta sessão usando superpowers:executing-plans.

**Goal:** Arquivo `.sh` único que instala a atualização do wallpaper a cada 1 hora.

**Architecture:** Bash independente com curl, adaptadores nativos e timer systemd.

**Tech Stack:** Bash 4.3+, coreutils, util-linux, curl, systemd.

**Spec:** `docs/superpowers/specs/2026-11-05-wallpaper-design.md`

## Global Constraints

- Distribuição apenas de `install.sh`. Sem Python e sem configuração de bloqueadores.
- URL HTTPS fixa, limite 25 MiB, nenhuma alteração no desktop de desenvolvimento.
- Reinstalação idempotente, retomada no login, estado seguro e desinstalação.

## Execução

- [x] Escrever `tests/test.sh` com comandos externos controlados; confirmar falha da versão Python.
- [x] Substituir o instalador pelo Bash independente e implementar os sete adaptadores.
- [x] Testar falhas de rede, HTML, truncamento, aplicação, login e concorrência.
- [x] Validar instalação/reinstalação/remoção com caminhos contendo espaços e caracteres especiais.
- [x] Verificar units e autostart com as ferramentas reais, sem habilitá-los.
- [x] Atualizar README/CI e remover a implementação e os testes Python.
- [x] Executar a verificação final de sintaxe, testes e download real do `.sh`.

Entrega local; sem criação de remoto, commit ou publicação. Validação visual em cada
desktop não faz parte da verificação automatizada disponível nesta máquina.
