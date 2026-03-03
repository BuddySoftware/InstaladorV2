# 🚀 Instalador OPLANO

Automatize a implantação do OPLANO em poucos minutos. Este instalador prepara o servidor, instala dependências, aplica otimizações, configura os serviços Docker e deixa tudo rodando com HTTPS/SSL automático via Traefik.

## 📋 Índice

- [O que este instalador faz](#-o-que-este-instalador-faz)
- [Características principais](#-características-principais)
- [Pré-requisitos](#-pré-requisitos)
- [Checklist antes de começar](#-checklist-antes-de-começar)
- [Guia de instalação passo a passo](#-guia-de-instalação-passo-a-passo)
- [Opções de instalação](#-opções-de-instalação)
- [O que é instalado automaticamente](#-o-que-é-instalado-automaticamente)
- [Comandos úteis](#-comandos-úteis)
- [Solução de problemas](#-solução-de-problemas)
- [Segurança e boas práticas](#-segurança-e-boas-práticas)
- [Suporte e próximos passos](#-suporte-e-próximos-passos)

## 🎯 O que este instalador faz

Em uma única execução, o instalador:

1. **Verifica o servidor** (Linux) e instala Docker, Docker Compose e Node.js automaticamente.
2. **Aplica otimizações de performance** no sistema operacional e no Docker daemon.
3. **Coleta informações** (domínios, e-mail, integrações) com perguntas simples e exemplos.
4. **Gera senhas fortes** automaticamente (banco, Redis, RabbitMQ, JWT, etc.).
5. **Configura variáveis de ambiente** e gera o arquivo `.env` completo.
6. **Copia e ajusta o `docker-compose.yml`** com base nas suas respostas.
7. **Baixa e inicia os containers** com certificados HTTPS válidos.
8. **Mostra um resumo final** com os dados de acesso e comandos úteis.

Tudo isso sem exigir conhecimentos avançados de Linux ou Docker.

## ✨ Características principais

### 🤖 Automação completa
- Pergunta apenas o essencial (e sempre com exemplos).
- Detecta se é nova instalação ou atualização.
- Reaproveita configurações antigas quando você atualiza.

### 🔒 Segurança integrada
- Certificados SSL gratuitos automáticos (Let's Encrypt via Traefik).
- Senhas longas e aleatórias geradas automaticamente.
- Containers isolados em rede privada Docker.

### 📦 Serviços prontos para produção
1. **Traefik** – Proxy reverso com HTTPS automático.
2. **Backend** – API do OPLANO (Node.js).
3. **Frontend** – Interface web (ReactJs).
4. **PostgreSQL 16** – Banco de dados otimizado.
5. **PgBouncer** – Pool de conexões.
6. **Redis (Valkey 7.2)** – Cache e gerenciamento de sessões.
7. **RabbitMQ 3.13** – Filas para processamento de mensagens.

## 🛠️ Pré-requisitos

### 💻 Sistema operacional compatível
- ✅ Ubuntu 22.04 ou superior (recomendado)
- ✅ Debian 11 ou superior

### 🖥️ Recursos mínimos do servidor

| Componente       | Mínimo         | Recomendado       | Ideal             |
| ---------------- | -------------- | ----------------- | ----------------- |
| **CPU**          | 4 núcleos      | 8 núcleos         | 8+ núcleos        |
| **Memória RAM**  | 8 GB           | 16 GB             | 16+ GB            |
| **Armazenamento**| 60 GB          | 100 GB SSD        | 100+ GB NVMe SSD  |
| **Conexão**      | 100 Mbps       | 1 Gbps            | 1 Gbps+           |

### 🌐 Domínios necessários

Você precisa de **2 subdomínios**, ambos apontando (registro tipo A) para o IP público do servidor:

| Domínio                | Para que serve       | Exemplo               |
| ---------------------- | -------------------- | --------------------- |
| Frontend (interface)   | Painel web do OPLANO | `app.seudominio.com`  |
| Backend (API)          | API do sistema       | `api.seudominio.com`  |

⚠️ **Importante:** sem os domínios apontados, o SSL não será gerado.

### 🔑 Token do GitHub (GHCR)

Necessário apenas para quem usa imagens prontas hospedadas no GitHub Container Registry (opções 1 e 2 do instalador).

Como gerar:
1. Acesse <https://github.com/settings/tokens>.
2. Clique em **Generate new token (classic)**.
3. Nome sugerido: `Docker Registry`.
4. Marque **apenas** o escopo `read:packages`.
5. Gere e copie o token (não será exibido novamente!).

## ✅ Checklist antes de começar

- [ ] Servidor Linux atualizado com acesso SSH e sudo/root.
- [ ] Domínios `app.seudominio.com` e `api.seudominio.com` apontando para o servidor.
- [ ] Portas **80** e **443** liberadas no firewall (Caso esteja habilitado).
- [ ] 60 GB livres em disco (mínimo).
- [ ] Token do GitHub (se for usar imagens hospedadas no GHCR).

## 🧭 Guia de instalação passo a passo

### 1. Conecte-se ao servidor

```bash
ssh root@IP_DO_SERVIDOR
# ou
ssh seu_usuario@IP_DO_SERVIDOR
```

### 2. Atualize sua vps

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

```bash
sudo reboot
```

### 3. Baixe o instalador

```bash
cd /root
git clone https://github.com/BuddySoftware/InstaladorV2.git
cd instalador
```

### 4. Dê permissão de execução e rode o script

```bash
chmod +x install.sh
./install.sh
```

### 5. Escolha a opção **1 – Nova Instalação (GHCR)**

```
🐳 Imagens Remotas (GHCR) - Recomendado
  1) Nova Instalação (usando imagens do GHCR)
```

### 5. Responda às perguntas (com exemplos na tela)

| Pergunta                                   | O que digitar                                      |
| ------------------------------------------ | -------------------------------------------------- |
| Ambiente (Produção ou Desenvolvimento)     | Digite **1** para Produção (tag `latest`).         |
| Usuário do GHCR                            | Pressione **Enter** para usar `oplanov2-entrega`.        |
| Repositório do GHCR                        | Pressione **Enter** para usar `entrega-oplanov2`.      |
| E-mail para SSL                            | Digite um e-mail válido (receberá alertas SSL).    |
| Domínio do FRONTEND                        | Ex.: `app.seudominio.com`.                         |
| Domínio do BACKEND                         | Ex.: `api.seudominio.com`.                         |
| Integrações Facebook / Gerencianet         | Pressione **Enter** se não for usar agora.         |
| MASTER_KEY                                 | Pressione **Enter** para gerar automaticamente.    |
| Número de suporte                          | Ex.: `5511999999999` (DDD + número, só dígitos).   |
| Credenciais (Banco/Redis/RabbitMQ)         | Escolha **Gerar automaticamente (Recomendado)**.   |
| Usuário + Token do GitHub (login GHCR)     | Informe seu usuário e cole o token gerado.         |

### 6. Confirme o resumo final

O instalador mostrará tudo o que será aplicado. Digite `s` para continuar.

### 7. Aguarde a instalação

Etapas executadas automaticamente:
1. Instala Docker / Docker Compose / Node.js (se necessário).
2. Aplica otimizações do sistema e do Docker.
3. Salva o arquivo `.env` em `/root/oplano/`.
4. Copia o `docker-compose.yml` e ajusta as imagens.
5. Gera arquivos extras (PgBouncer, RabbitMQ, etc.).
6. Faz login no GitHub Container Registry.
7. Baixa as imagens e sobe os containers.

Tempo médio: **5 a 10 minutos**, dependendo da velocidade da internet e do servidor.

### 8. Acesse o sistema

- Frontend: `https://app.seudominio.com`
- Backend (API): `https://api.seudominio.com`

> O certificado SSL pode levar até 2 minutos para ser emitido no primeiro acesso.

### 9. Faça backup do `.env`

O arquivo `/root/oplano/.env` contém todas as senhas geradas. Baixe e guarde em local seguro.

## 📦 Opções de instalação

O instalador apresenta 5 opções no menu inicial:

| Opção | Nome                                      | Quando usar                                        | Preserva dados? | Requisitos                              |
| ----- | ----------------------------------------- | -------------------------------------------------- | --------------- | --------------------------------------- |
| 1     | Nova instalação (GHCR)                    | Primeira vez ou reinstalação usando imagens prontas| N/A             | Token GHCR                              |
| 2     | Atualizar instalação (GHCR)               | Atualizar para a versão mais recente               | ✅ Sim          | Instalação prévia via GHCR              |
| 3     | Nova instalação (build local)             | Compilar imagens a partir do código-fonte          | N/A             | Repositório Git + recursos extras       |
| 4     | Atualizar instalação (build local)        | Atualizar re-buildando as imagens                  | ✅ Sim          | Build local prévio                       |
| 5     | Reset completo (⚠️ destrutivo)            | Remover tudo e começar do zero                     | ❌ Não          | Confirmação manual                      |

### Recomendações rápidas
- Use **Opção 1** para novas instalações em produção.
- Use **Opção 2** para atualizar sem perder dados.
- Opções 3 e 4 são para quem precisa compilar as imagens manualmente (desenvolvedores).
- A opção 5 apaga tudo (containers, volumes, `.env`, código-clone). Faça backup antes!

## 🔧 O que é instalado automaticamente

### 1. Dependências do sistema

| Pacote         | Para que serve                             |
| -------------- | ------------------------------------------- |
| Docker         | Executar os containers do OPLANO            |
| Docker Compose | Orquestrar os containers em conjunto        |
| Node.js 20.x   | Obter a versão mais recente do WhatsApp Web |

### 2. Otimizações do Linux

- `limits.conf`: aumenta arquivos/proc por usuário (65.536 / 32.768).
- `sysctl.conf`: ajustes de TCP/IP, memória, inotify e performance.
- `daemon.json` do Docker: limita logs (10MB x 3 arquivos), habilita overlay2 e ulimits.

As alterações são aplicadas apenas se ainda não existirem (sem duplicações).

### 3. Containers e funções

| Serviço              | Imagem                                    | Função principal                                 |
| -------------------- | ----------------------------------------- | ------------------------------------------------ |
| Traefik              | `traefik:v2.11.7`                         | Proxy reverso com HTTPS automático               |
| Backend              | `ghcr.io/<org>/<repo>/backend:${DOCKER_TAG}` | API OPLANO, migra DB, integra WhatsApp           |
| Frontend             | `ghcr.io/<org>/<repo>/frontend:${DOCKER_TAG}`| Interface web para usuários                      |
| PostgreSQL           | `postgres:16.10`                          | Banco de dados principal                         |
| PgBouncer            | `edoburu/pgbouncer`                       | Pool de conexões para o PostgreSQL               |
| Redis (Valkey)       | `valkey/valkey:7.2-alpine`                | Cache, sessões, filas rápidas                    |
| RabbitMQ             | `rabbitmq:3.13-management`                | Fila de mensagens para processamento assíncrono  |

### 4. Volumes persistentes

| Volume                | Conteúdo                                |
| --------------------- | --------------------------------------- |
| `traefik_letsencrypt` | Certificados SSL                        |
| `postgres_volume`     | Dados do banco                          |
| `redis_volume`        | Dados do Redis                          |
| `rabbitmq_volume`     | Filas persistidas                       |
| `backend_private`     | Sessões WhatsApp e arquivos privados    |
| `backend_public`      | Uploads públicos (imagens, anexos)      |

### 5. Arquivos gerados em `/root/oplano`

- `.env`: todas as variáveis do sistema (guarde com segurança!).
- `docker-compose.yml`: orquestra todos os serviços.
- `config/pgbouncer/pgbouncer.ini` e `userlist.txt`.
- `config/rabbitmq/rabbitmq.conf` (ajustes de usuário/senha).

### 6. Senhas e chaves automáticas

O instalador gera, por padrão, credenciais seguras:

| Variável             | Tipo de dado | Uso                                         |
| -------------------- | ------------ | ------------------------------------------- |
| `DB_NAME`, `DB_USER` | Strings com prefixo | Identificação do banco               |
| `DB_PASS`            | Senha forte  | Acesso ao PostgreSQL                        |
| `RABBIT_USER/PASS`   | Senha forte  | Acesso ao RabbitMQ                          |
| `REDIS_PASSWORD`     | Senha forte  | Autenticação no Redis                       |
| `JWT_SECRET`         | Base64       | Autenticação de usuários                    |
| `JWT_REFRESH_SECRET` | Base64       | Renovação de tokens                         |
| `MASTER_KEY`         | String longa | Criptografia interna do OPLANO              |
| `VERIFY_TOKEN`       | String       | Verificação de webhooks (Facebook)          |

### 7. Consumo estimado de recursos (carga moderada)

| Recurso      | Consumo aproximado |
| ------------ | ------------------ |
| Backend      | 500 MB – 2 GB RAM  |
| PostgreSQL   | 500 MB – 1 GB RAM  |
| Redis        | 100 – 300 MB RAM   |
| RabbitMQ     | 200 – 400 MB RAM   |
| Frontend     | 100 – 200 MB RAM   |
| Traefik      | <100 MB RAM        |

Recomenda-se manter pelo menos **4 GB de RAM livres** para picos e atualizações.

## 📝 Comandos úteis

Todos os comandos abaixo devem ser executados em `/root/oplano`.

### 🔍 Status e monitoramento

```bash
cd /root/oplano
docker compose ps             # Status dos serviços
docker stats                  # Uso de CPU/RAM em tempo real
docker ps                     # Containers rodando
```

### 📜 Logs

```bash
docker compose logs -f                 # Todos os serviços
docker compose logs -f backend         # Somente backend
docker compose logs -f frontend        # Somente frontend
docker compose logs -f traefik         # Verificar SSL
docker compose logs --tail=100 backend # Últimas 100 linhas
```

Use `Ctrl+C` para sair dos logs ao vivo.

### 🔄 Reiniciar serviços

```bash
docker compose restart                 # Reinicia tudo
docker compose restart backend         # Reinicia apenas o backend
docker compose stop && docker compose start   # Parar e iniciar novamente
docker compose down && docker compose up -d   # Recriar containers (mantém dados)
```

### 💾 Backup e restauração do banco

```bash
# Criar backup
docker exec whaticket-postgres pg_dump -U $DB_USER $DB_NAME > backup_$(date +%Y%m%d_%H%M%S).sql

# Restaurar backup
cat backup_20240101_120000.sql | docker exec -i whaticket-postgres psql -U $DB_USER -d $DB_NAME
```

### 🔐 Acessar shells dentro dos containers

```bash
docker exec -it backend /bin/bash                                # Terminal do backend
docker exec -it whaticket-postgres psql -U $DB_USER -d $DB_NAME   # Cliente psql
docker exec -it whaticket-redis valkey-cli -a $REDIS_PASSWORD    # CLI do Redis
```

### 🧹 Limpeza e manutenção

```bash
docker system df              # Ver tamanho ocupado pelo Docker
docker image prune -a         # Remover imagens antigas
docker volume prune           # Remover volumes órfãos (cuidado!)
```

## 🛠️ Solução de problemas

### 1. Certificado SSL não funciona

1. Confirme os domínios:
  ```bash
  ping app.seudominio.com
  ping api.seudominio.com
  ```
2. Verifique se as portas 80/443 estão liberadas.
3. Veja os logs do Traefik:
  ```bash
  docker compose logs -f traefik | grep -i acme
  ```
4. Forçar novo certificado (armazenamento será recriado):
  ```bash
  docker compose stop traefik
  docker volume rm oplano_traefik_letsencrypt
  docker compose up -d traefik
  ```

### 2. Backend não conecta no banco

1. Verifique o status:
  ```bash
  docker compose ps | grep postgres
  docker compose ps | grep pgbouncer
  ```
2. Teste a conexão manualmente:
  ```bash
  docker exec -it whaticket-postgres psql -U $DB_USER -d $DB_NAME
  ```
3. Confira as credenciais em `/root/oplano/.env` (linhas `DB_*`).
4. Reinicie a cadeia banco → pool → backend:
  ```bash
  docker compose restart whaticket-postgres whaticket-pgbouncer backend
  ```

### 3. WhatsApp não conecta ou QR code não aparece

1. Cheque a versão `CLIENT_REVISION` no `.env`.
2. Atualize o instalador (opção 2) para forçar busca da versão mais recente.
3. Se necessário, limpe sessões antigas (cuidado: desconecta tudo):
  ```bash
  docker compose stop backend
  docker volume rm oplano_backend_private
  docker volume create oplano_backend_private
  docker compose up -d backend
  ```

### 4. Containers reiniciando em loop

1. Analise os logs do serviço em questão (ex.: backend).
2. Verifique se todos os serviços dependentes estão saudáveis (`docker compose ps`).
3. Garanta que o servidor tem memória/disco suficientes (`free -h`, `df -h`).
4. Recrie os containers mantendo dados:
  ```bash
  docker compose down
  docker compose up -d
  ```

### 5. Porta 80 ou 443 em uso

1. Identifique o processo:
  ```bash
  sudo lsof -i :80
  sudo lsof -i :443
  ```
2. Desabilite serviços extras (Apache/Nginx) e reinicie o Traefik.

### 6. Problemas gerais ou instalação travada

1. Certifique-se de estar logado como `root` ou usar `sudo`.
2. Teste a conectividade com a internet (`ping 8.8.8.8`).
3. Verifique espaço em disco (`df -h`).
4. Execute o instalador novamente e escolha **Opção 2** (Atualizar).
5. Se necessário, use a opção 5 (Reset) e instale do zero (faça backup antes!).

## 🔒 Segurança e boas práticas

1. **Proteja o arquivo `.env`** (`/root/oplano/.env`). Ele contém todas as senhas.
2. **Implemente backups automáticos** (ex.: cron diário para `pg_dump`).
3. **Atualize o sistema** regularmente (`apt update && apt upgrade`).
4. **Restrinja o acesso SSH** (troque porta padrão, use chave em vez de senha).
5. **Monitore recursos** (CPU/RAM/disco) com ferramentas como `htop`, `glances` ou Prometheus/Grafana.
6. **Mantenha o firewall ativo** e libere apenas portas necessárias (80, 443, SSH).

### Portas utilizadas

| Porta | Serviço                | Exposição |
| ----- | ---------------------- | --------- |
| 80    | Traefik (HTTP)         | Pública   |
| 443   | Traefik (HTTPS)        | Pública   |
| 5432  | PostgreSQL             | Interna   |
| 6432  | PgBouncer              | Interna   |
| 6379  | Redis                  | Interna   |
| 5672  | RabbitMQ               | Interna   |
| 8080  | Backend (interno)      | Interna   |
| 3000  | Frontend (interno)     | Interna   |

## 💬 Suporte e próximos passos

1. Revise os logs (`docker compose logs -f`).
2. Consulte este README sempre que precisar relembrar comandos.
3. Em caso de dúvidas, abra uma issue no repositório oficial.

---

Processo de deploy 🚀 por [Joseph Fernandes](https://github.com/JobasFernandes)
