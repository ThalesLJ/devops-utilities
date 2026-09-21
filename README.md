<p align="center">
  <h1 align="center">Inova e-Business · DevOps Utilities</h1>
  <p align="center">
    Conjunto de utilitários e scripts de DevOps mantidos pela
    <strong>Inova e-Business</strong>.
  </p>
  <p align="center">
    <a href="https://github.com/inovaebiz/devops-utilities/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/inovaebiz/devops-utilities?color=blue"></a>
    <a href="https://github.com/inovaebiz/devops-utilities"><img alt="GitHub repo stars" src="https://img.shields.io/github/stars/inovaebiz/devops-utilities?color=yellow"></a>
    <a href="https://github.com/inovaebiz/devops-utilities"><img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/inovaebiz/devops-utilities"></a>
    <a href="https://github.com/inovaebiz/devops-utilities/issues"><img alt="GitHub issues" src="https://img.shields.io/github/issues/inovaebiz/devops-utilities"></a>
    <a href="https://github.com/inovaebiz/devops-utilities/pulls"><img alt="GitHub pull requests" src="https://img.shields.io/github/issues-pr/inovaebiz/devops-utilities"></a>
    <img alt="Made with Bash" src="https://img.shields.io/badge/made%20with-Bash-4EAA25">
  </p>
</p>

---

## 📑 Sumário

- [📑 Sumário](#-sumário)
- [💡 Sobre o projeto](#-sobre-o-projeto)
- [🧰 Requisitos](#-requisitos)
- [🚀 Instalação](#-instalação)
  - [Comando global `inovatils`](#comando-global-inovatils)
  - [Menu interativo (sem o comando global)](#menu-interativo-sem-o-comando-global)
  - [Instalação direta (sem menu)](#instalação-direta-sem-menu)
- [💻 Comandos disponíveis](#-comandos-disponíveis)
- [📦 Scripts disponíveis](#-scripts-disponíveis)
- [⚖️ Aviso legal](#️-aviso-legal)
- [🤝 Contribuindo](#-contribuindo)
- [📄 Licença](#-licença)

---

## 💡 Sobre o projeto

Este repositório reúne scripts, ferramentas e automações de infraestrutura e
DevOps utilizados internamente pela **Inova e-Business**. Ele é disponibilizado
publicamente com o objetivo de compartilhar boas práticas e facilitar o
trabalho de outras equipes.

## 🧰 Requisitos

- **Linux**, **macOS** ou **Windows** (via Git Bash / MSYS2 / WSL)
- **Docker** instalado e em execução (Docker Desktop no macOS/Windows)
- **Bash** 4+
- **curl** para baixar os scripts

## 🚀 Instalação

Este repositório usa um **gerenciador** (`install.sh`) que instala, rastreia,
atualiza e remove os scripts, além de informar quais estão desatualizados em
relação ao repositório. Depois da primeira instalação, use o comando global
**`inovatils`** — chamável de qualquer diretório.

### Comando global `inovatils`

Instale o comando global (uma única vez):

```bash
curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh | sudo bash -s -- inovatils
```
ou, se você já baixou o install.sh:
```bash
sudo bash install.sh inovatils
```

Depois, use `inovatils` de qualquer lugar:

```bash
inovatils                  # abre o menu interativo
inovatils list             # lista scripts + status/versões
inovatils install          # instala todos os scripts disponíveis (atalho: inovatils i)
inovatils uninstall        # desinstala todos os scripts (atalho: inovatils u)
inovatils update           # atualiza todos os instalados
inovatils self-update      # atualiza o próprio inovatils + gerenciador
inovatils --help
```

> `inovatils` é um wrapper fino instalado em `/usr/local/bin/inovatils`;
> o gerenciador em si fica em `~/.inova-devops/install.sh` e é atualizado
> junto com `self-update`. Funciona em Linux, macOS e Windows (Git Bash/MSYS2/WSL).

### Menu interativo (sem o comando global)

Baixe o gerenciador e abra o menu:

```bash
curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh -o /tmp/install.sh
sudo bash /tmp/install.sh
```

### Instalação direta (sem menu)

Para baixar e instalar um script em uma única linha:

```bash
curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh | sudo bash -s -- <script> [diretorio]
```

Exemplo com o `docker-cleanup.sh` (instala em `/usr/local/sbin` com `chmod 750`):

```bash
curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh | sudo bash -s -- docker-cleanup.sh
```

Ou instale em um diretório customizado:

```bash
curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh | sudo bash -s -- docker-cleanup.sh /opt/scripts
```

> ℹ️ Os scripts são instalados em `/usr/local/sbin` (que exige privilégios de
> root, daí o `sudo`). Sempre revise o conteúdo antes de executar.

## 💻 Comandos disponíveis

| Comando                        | Descrição                                                                                        | Alias / Atalho                                             | Exemplo                                    |
| ------------------------------ | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- | ------------------------------------------ |
| `inovatils`                    | Abre o menu interativo com interface no terminal (TUI) para gerenciar e executar scripts.        | —                                                          | `inovatils`                                |
| `inovatils list`               | Lista todos os utilitários do repositório exibindo versões local, remota e status de instalação. | `inovatils status`                                         | `inovatils list`                           |
| `inovatils install`            | Baixa e instala todos os scripts disponíveis do repositório em `/usr/local/sbin/`.              | `inovatils i`                                              | `inovatils install` *(ou `inovatils i`)*   |
| `inovatils install <script>`   | Baixa e instala o script informado em `/usr/local/sbin/` com permissão de execução.              | `inovatils i <script>`, `inovatils <script>`               | `inovatils install service-docker`         |
| `inovatils uninstall`          | Desinstala e remove todos os scripts instalados do sistema.                                      | `inovatils u`                                              | `inovatils uninstall` *(ou `inovatils u`)* |
| `inovatils uninstall <script>` | Remove e desinstala o script indicado do sistema.                                                | `inovatils u <script>`, `inovatils remove`, `inovatils rm` | `inovatils uninstall disk-health.sh`       |
| `inovatils update`             | Percorre e atualiza automaticamente todos os scripts atualmente instalados no sistema.           | —                                                          | `inovatils update`                         |
| `inovatils update <script>`    | Atualiza um script específico instalado para a versão mais recente publicada no repositório.     | —                                                          | `inovatils update service-docker`          |
| `inovatils self-update`        | Atualiza o próprio executável `inovatils` e o gerenciador local para a versão mais recente.      | —                                                          | `inovatils self-update`                    |
| `inovatils --help`             | Exibe o manual de ajuda detalhado com os comandos e parâmetros aceitos.                          | `inovatils -h`                                             | `inovatils --help`                         |

## 📦 Scripts disponíveis

| Script                                             | Descrição                                                                                                                                                                                  | Plataformas                              | Instalação                                                                                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [`docker-cleanup.sh`](./docker-cleanup.sh)         | Limpeza automática de imagens, containers parados, redes não utilizadas e cache de build do Docker, preservando sempre os volumes.                                                         | Linux · macOS · Windows (Docker Desktop) | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- docker-cleanup.sh`     |
| [`sys-update-checker.sh`](./sys-update-checker.sh) | Analisa pacotes, kernel e serviços que precisam de atualização e aplica as atualizações de forma segura após aceite (modo interativo ou `--yes`).                                          | Linux · macOS · Windows                  | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- sys-update-checker.sh` |
| [`threat-scan.sh`](./threat-scan.sh)               | Varredura somente-leitura que identifica indícios de vírus, worms, malwares, mineradores, backdoors e persistências suspeitas (processos, rede, agendamentos, usuários, arquivos, kernel). | Linux · macOS · Windows                  | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- threat-scan.sh`        |
| [`disk-health.sh`](./disk-health.sh)               | Diagnóstico de disco, inodes e crescimento de logs; oferece limpezas seguras de journal, logs rotacionados e arquivos temporários antigos, reportando espaço reclamável do Docker.         | Linux · macOS · Windows                  | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- disk-health.sh`        |
| [`opencode-installer.sh`](./opencode-installer.sh) | Baixa e instala o OpenCode (AI coding agent) pelo melhor método da plataforma (script oficial, Homebrew, npm, Chocolatey, Scoop, pacman).                                                  | Linux · macOS · Windows                  | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- opencode-installer.sh` |
| [`service-docker`](./service-docker)               | Instalação e atualização segura do Docker Engine e Compose V2 com baseline de daemon (`daemon.json`, live-restore, rotação de logs), usuário de sistema isolado `docker-user`, rollback (`--rollback`) e desinstalação profunda (`--uninstall`). | Linux                                    | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- service-docker`        |
| [`service-evolution-api`](./service-evolution-api) | Instalação, ciclo de vida, backups diários automáticos (com suporte a backup a frio e retenção de 10 arquivos), usuário isolado `evolution-user`, limites de recursos (~10 instâncias), versão fixa v2.3.7, atualização dinâmica (`--update`) e purga profunda (`--uninstall`) da Evolution API v2 em Linux. Consulte o [Guia de Otimização e Monitoramento](./docs/resource-tuning-and-monitoring.md). | Linux                                    | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- service-evolution-api` |
| [`install.sh`](./install.sh)                       | Gerenciador/instalador: baixa, rastreia versões, atualiza e remove os scripts, com menu interativo e comandos de linha.                                                                    | Linux · macOS · Windows                  | —                                                                                                                                 |
| [`inovatils`](./inovatils)                         | Comando global (wrapper) para o gerenciador — chamável de qualquer diretório (`inovatils list`, `inovatils update`, ...).                                                                  | Linux · macOS · Windows                  | `curl -fsSL https://raw.githubusercontent.com/ThalesLJ/devops-utilities/main/install.sh \| sudo bash -s -- inovatils`             |

## ⚖️ Aviso legal

> **Este é um projeto público de uso interno da Inova e-Business.**
>
> O código é fornecido "como está" (*as is*), sem garantias de qualquer tipo.
> A Inova e-Business **não se responsabiliza** pelo uso que terceiros façam
> deste repositório, nem por eventuais danos, perdas ou problemas decorrentes
> da sua utilização.
>
> O uso dos scripts e utilitários aqui presentes é de inteira
> responsabilidade de quem os utilizar.

## 🤝 Contribuindo

Este é um projeto público e colaborações são bem-vindas. Para contribuir:

1. Faça um *fork* do repositório.
2. Crie uma *branch* para sua alteração (`git checkout -b feature/minha-mudanca`).
3. Faça o *commit* das suas alterações (`git commit -m 'Adiciona minha mudança'`).
4. Envie para o seu *fork* (`git push origin feature/minha-mudanca`).
5. Abra um *Pull Request*.

## 📄 Licença

Distribuído sob a licença [MIT](./LICENSE).

---

<p align="center">
  Mantido com ❤️ pela <strong>Inova e-Business</strong>
</p>
