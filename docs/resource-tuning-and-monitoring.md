# Guia Operacional: Otimização de Recursos & Monitoramento em Tempo Real

**Stack de Serviços**: Evolution API, PostgreSQL 15, Redis 7  
**Localização**: `/opt/evolution-api`  
**Arquivo de Configuração**: `/opt/evolution-api/.env`

---

## 1. Visão Geral

Por padrão, o Docker permite que os containers consumam memória e núcleos de CPU ilimitados do sistema operacional. Embora flexível, isso gera graves riscos de estabilidade: um vazamento de memória (*memory leak*) ou picos de processamento de mídias pesadas podem acionar o mecanismo *Out-Of-Memory (OOM) Killer* do kernel Linux, finalizando processos aleatórios do host ou derrubando serviços essenciais.

Para garantir a resiliência em ambiente de produção, a stack é pré-configurada com **reservas flexíveis** (*soft reservations* — memória garantida alocada pelo kernel) e **limites rígidos** (*hard limits* — teto máximo imposto por cgroups).

---

## 2. Baseline de Recursos (~10 Instâncias de WhatsApp)

A configuração padrão gerada pelo utilitário `service-evolution-api` é dimensionada para suportar confortavelmente cerca de **10 instâncias simultâneas do WhatsApp**:

| Container do Serviço | Reserva Mínima (`mem_reserve`) | Limite Máximo (`mem_limit`) | Alocação de CPU (`cpus`) | Variável Padrão no `.env` |
| :--- | :--- | :--- | :--- | :--- |
| **`evolution_api`** | `512m` (0.5 GB) | `2048m` (2.0 GB) | `1.5` | `EVOLUTION_MEM_LIMIT`, `EVOLUTION_MEM_RESERVE`, `EVOLUTION_CPUS` |
| **`evolution_postgres`** | `128m` | `512m` (0.5 GB) | `1.0` | `POSTGRES_MEM_LIMIT`, `POSTGRES_MEM_RESERVE`, `POSTGRES_CPUS` |
| **`evolution_redis`** | `64m` | `256m` (0.25 GB) | `0.5` | `REDIS_MEM_LIMIT`, `REDIS_MEM_RESERVE`, `REDIS_CPUS` |
| **Total Estimado da Stack** | **~704 MB** | **~2.8 GB** | **3.0 Núcleos** | - |

### Fórmula de Dimensionamento por Instância de WhatsApp:
- **Runtime base da Evolution API**: ~250 MB - 350 MB (motor Node.js, servidor Express, manipuladores WebSocket).
- **Por instância de WhatsApp (Baileys) conectada**: ~70 MB - 120 MB de RAM, dependendo do tráfego de mensagens.
- **Margem de segurança para mídias (*buffer cushion*)**: ~300 MB - 500 MB para absorver com segurança rajadas temporárias de áudios, imagens e documentos sem sobrecarregar o *Garbage Collector* (GC) do Node.js.
- **PostgreSQL**: ~150 MB - 250 MB para pool de conexões ativas, conversas e índices do histórico de mensagens.
- **Redis**: ~50 MB - 100 MB para cache temporário de sessões e filas de mensagens.

---

## 3. Guia de Dimensionamento para Escala

Utilize as seguintes recomendações ao ajustar a stack para diferentes perfis de carga:

| Instâncias Simultâneas | RAM Mínima no Host | `EVOLUTION_MEM_LIMIT` | `EVOLUTION_MEM_RESERVE` | `POSTGRES_MEM_LIMIT` |
| :--- | :--- | :--- | :--- | :--- |
| **1 – 3 instâncias** | 2 GB | `1024m` (1.0 GB) | `384m` | `384m` |
| **4 – 10 instâncias** *(Padrão)* | 4 GB | `2048m` (2.0 GB) | `512m` | `512m` |
| **11 – 25 instâncias** | 8 GB | `4096m` (4.0 GB) | `1024m` | `1024m` |
| **26 – 50 instâncias** | 16 GB | `8192m` (8.0 GB) | `2048m` | `2048m` |

---

## 4. Como Alterar e Atualizar os Limites de Recursos

Todos os limites de recursos são parametrizados em `/opt/evolution-api/.env`. Você **não** precisa editar o `docker-compose.yml`.

### Passo 1: Abrir o Arquivo de Ambiente
```bash
sudo nano /opt/evolution-api/.env
```

### Passo 2: Ajustar as Variáveis de Recursos
Localize a seção de limites de recursos e altere os valores conforme a sua necessidade:
```env
# ==============================================================================
# Limites de Recursos & Otimização
# ==============================================================================
EVOLUTION_MEM_LIMIT=3072m
EVOLUTION_MEM_RESERVE=1024m
EVOLUTION_CPUS=2.0

POSTGRES_MEM_LIMIT=1024m
POSTGRES_MEM_RESERVE=256m
POSTGRES_CPUS=1.5

REDIS_MEM_LIMIT=512m
REDIS_MEM_RESERVE=128m
REDIS_CPUS=0.5
```

### Passo 3: Aplicar os Novos Limites
Reinicie a stack usando o próprio utilitário de gerenciamento:
```bash
sudo service-evolution-api --restart
```
*(Ou manualmente através de: `cd /opt/evolution-api && sudo docker compose up -d`)*

---

## 5. Monitoramento em Tempo Real

### A. Fluxo Contínuo no Terminal
Para monitorar CPU, RAM, I/O de rede e limites de memória dos containers em tempo real:
```bash
docker stats evolution_api evolution_postgres evolution_redis
```

**O que analisar no `docker stats`:**
- `MEM USAGE / LIMIT`: Mostra o consumo atual de memória em relação ao limite máximo configurado.
- `MEM %`: Se o `MEM %` permanecer constantemente acima de **80%**, o Garbage Collector do Node.js começará a gastar ciclos excessivos de CPU tentando liberar memória, causando lentidão. Considere elevar o `EVOLUTION_MEM_LIMIT`.
- `CPU %`: Picos temporários de 100% a 150% durante envio/recebimento de mídias ou geração de QR Code são normais. CPU constantemente elevada indica loop de processamento ou limite de CPU subdimensionado.

### B. Snapshot Diagnóstico Único (Sem Stream)
Para verificações rápidas em rotinas de diagnóstico ou scripts:
```bash
docker stats evolution_api evolution_postgres evolution_redis --no-stream
```

### C. Inspeção de Memória do Host
Verifique o consumo global de memória e espaço de swap do servidor Linux:
```bash
free -h
```

---

## 6. Identificação e Troubleshooting de Eventos OOM (Out Of Memory)

Se um container ultrapassar o valor definido em `mem_limit`, o kernel Linux encerrará o processo imediatamente (código de saída `137`).

### Como Verificar se um Container Sofreu OOM:
```bash
docker inspect evolution_api --format 'OOMKilled: {{.State.OOMKilled}}, ExitCode: {{.State.ExitCode}}'
```
- Se `OOMKilled: true`: O container excedeu o limite máximo estipulado. Aumente o `EVOLUTION_MEM_LIMIT` no arquivo `.env`.

### Consultar Logs do Kernel Linux Relacionados a OOM:
```bash
sudo dmesg -T | grep -i oom
sudo journalctl -k -g oom
```
