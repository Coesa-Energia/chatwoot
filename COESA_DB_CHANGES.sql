-- =====================================================================================
-- COESA - Alterações de banco e exemplos de dados do fork (PostgreSQL)
-- =====================================================================================
-- Este arquivo é MANTIDO A MÃO a cada mudança que mexe com dados ou estrutura:
--   * estrutura (DDL) de tabelas/colunas novas, sempre igual à migration correspondente;
--   * convenções de dados guardados em colunas jsonb (sem migration), com exemplos;
--   * consultas úteis de operação.
-- A fonte de verdade da estrutura continua sendo db/migrate + db/schema.rb. Aqui fica o resumo
-- legível para quem opera o sistema. Os exemplos usam ids fictícios: troque pelos seus.
--
-- Como atualizar: ao fazer uma mudança que toque banco ou jsonb, adicione uma seção nova no fim
-- (com a data) e uma linha no histórico abaixo.
--
-- HISTÓRICO
--   2026-10-12  conversation_user_states (fixar/arquivar por usuário)
--   2026-10-12  reações em mensagens (messages.content_attributes.reactions)
--   2026-10-12  confirmação de leitura do WhatsApp (conversations.additional_attributes / provider_config)
--   2026-10-12  segredo do webhook do WhatsApp (channel_whatsapp.provider_config.webhook_secret)
--   2026-10-12  plano e cobrança da conta (accounts.custom_attributes.saas_*)
--   2026-10-12  logo e layout da marca (active_storage + accounts.settings.brand_display)
--   2026-10-12  contato: TikTok, Instagram, X e GitHub deixaram de ser exibidos (sem alteração de banco)
--   2026-10-12  assinatura de mensagem desativada no chat (sem alteração de banco)
--   2026-10-13  acesso às conversas por agente em cada caixa (inbox_members.see_all_conversations)
--   2026-10-13  tela de conversas arquivadas e sidebar abrir/fechar (sem alteração de banco)
--   2026-10-14  arquivadas: continuam arquivadas até o usuário desarquivar (sem mudança de estrutura)
--   2026-10-13  marca: imagem do menu fechado, logo ao lado do nome e imagem junto ao texto (accounts.settings / Active Storage)
--   2026-10-14  rodizio por agente e time padrao da caixa (inbox_members.in_rotation, inboxes.default_team_id)
--   2026-10-15  integracoes (Dashboard Apps) por caixa de entrada (dashboard_apps.inbox_ids)
--   2026-10-20  RESUMO para a migracao da producao (secao no fim do arquivo)
--   2026-10-20  Modo Vendedor (accounts.settings.seller_mode) e ligacoes pelo telefone registradas na conversa do WhatsApp
--   2026-10-20  artigos "Exclusivo para IA" na Central de Ajuda (articles.ai_only); vendedores leem a Central de Ajuda
-- =====================================================================================


-- -------------------------------------------------------------------------------------
-- 1) Fixar e arquivar conversas por usuário
--    Migration: db/migrate/20261012120000_create_conversation_user_states.rb
--    Regra: o que um agente fixa/arquiva não muda a lista dos outros.
--    "Arquivada" = archived_at preenchido. Mensagem nova NÃO tira a conversa do arquivo: só o próprio
--    usuário desarquiva (a partir de 13/10; antes, mensagem nova desarquivava sozinha).
-- -------------------------------------------------------------------------------------
CREATE TABLE conversation_user_states (
  id              bigserial PRIMARY KEY,
  account_id      bigint      NOT NULL,
  user_id         bigint      NOT NULL,
  conversation_id bigint      NOT NULL,
  pinned_at       timestamp,
  archived_at     timestamp,
  created_at      timestamp   NOT NULL,
  updated_at      timestamp   NOT NULL
);
CREATE UNIQUE INDEX index_conversation_user_states_on_user_id_and_conversation_id
  ON conversation_user_states (user_id, conversation_id);
CREATE INDEX index_conversation_user_states_on_conversation_id ON conversation_user_states (conversation_id);
CREATE INDEX index_conversation_user_states_on_account_id      ON conversation_user_states (account_id);

-- Exemplo: o usuário 4 fixa a conversa 12 e arquiva a conversa 15
-- INSERT INTO conversation_user_states (account_id, user_id, conversation_id, pinned_at, archived_at, created_at, updated_at)
-- VALUES (1, 4, 12, now(), NULL, now(), now()),
--        (1, 4, 15, NULL, now(), now(), now());

-- Conversas fixadas de um usuário (máximo de 5, aplicado pela aplicação)
-- SELECT c.display_id, s.pinned_at
--   FROM conversation_user_states s JOIN conversations c ON c.id = s.conversation_id
--  WHERE s.user_id = 4 AND s.pinned_at IS NOT NULL ORDER BY s.pinned_at DESC;


-- -------------------------------------------------------------------------------------
-- 2) Reações em mensagens do WhatsApp Cloud (sem migration)
--    Guardadas na própria mensagem reagida: no máximo uma reação do cliente ('contact')
--    e uma do time ('business'). Remover a reação apaga a chave; sem reações, apaga 'reactions'.
-- -------------------------------------------------------------------------------------
-- Exemplo: o cliente reagiu com 👍 e o time com ❤️ à mensagem de source_id 'wamid.ABC'
-- UPDATE messages
--    SET content_attributes = jsonb_set(coalesce(content_attributes, '{}'::jsonb), '{reactions}',
--                                       '{"contact": "👍", "business": "❤️"}'::jsonb)
--  WHERE source_id = 'wamid.ABC';

-- Mensagens que têm reação
-- SELECT id, conversation_id, content_attributes -> 'reactions' AS reactions
--   FROM messages WHERE content_attributes ? 'reactions';


-- -------------------------------------------------------------------------------------
-- 3) Confirmação de leitura enviada ao cliente (WhatsApp Cloud, sem migration)
--    - conversations.additional_attributes.whatsapp_read_receipt_message_id guarda o último wamid
--      confirmado (evita reenviar).
--    - Para desligar em uma caixa: channel_whatsapp.provider_config.send_read_receipts = false.
-- -------------------------------------------------------------------------------------
-- Desligar a confirmação de leitura de um número (troque o phone_number)
-- UPDATE channel_whatsapp
--    SET provider_config = jsonb_set(provider_config, '{send_read_receipts}', 'false'::jsonb)
--  WHERE phone_number = '+5511999990001';


-- -------------------------------------------------------------------------------------
-- 4) Segredo do webhook do WhatsApp (sem migration)
--    channel_whatsapp.provider_config.webhook_secret: usado na URL do webhook do 360dialog e
--    na validação da assinatura X-Hub-Signature-256 (Cloud). Gerado pela aplicação; para
--    gerar nos canais antigos use a tarefa rake lib/tasks/whatsapp_webhook_security.rake.
-- -------------------------------------------------------------------------------------
-- Canais sem segredo
-- SELECT id, phone_number FROM channel_whatsapp WHERE coalesce(provider_config ->> 'webhook_secret', '') = '';


-- -------------------------------------------------------------------------------------
-- 5) Plano e cobrança da conta (sem migration)
--    accounts.custom_attributes, chaves saas_* (não usar 'plan_name': é do billing enterprise):
--      saas_plan, saas_trial_ends_at (AAAA-MM-DD), saas_paid_until (AAAA-MM-DD), saas_notes
--    Fim da cobertura = saas_paid_until, ou saas_trial_ends_at se não houver. Sem datas = não expira.
--    Job diário (03:00 UTC, config/schedule.yml) suspende contas vencidas há mais de
--    SAAS_GRACE_DAYS dias (padrão 3), registrando categoria 'non_payment' em
--    accounts.internal_attributes.suspensions. Editado em SuperAdmin > Conta > Plano e cobrança.
-- -------------------------------------------------------------------------------------
-- Exemplo: conta 1 no plano Pro, pago até 2026-11-10
-- UPDATE accounts
--    SET custom_attributes = coalesce(custom_attributes, '{}'::jsonb)
--        || '{"saas_plan": "Pro", "saas_paid_until": "2026-11-10", "saas_notes": "Pix todo dia 10"}'::jsonb
--  WHERE id = 1;

-- Contas que vencem nos próximos 7 dias
-- SELECT id, name, custom_attributes ->> 'saas_plan' AS plano,
--        coalesce(custom_attributes ->> 'saas_paid_until', custom_attributes ->> 'saas_trial_ends_at') AS fim
--   FROM accounts
--  WHERE status = 0
--    AND coalesce(custom_attributes ->> 'saas_paid_until', custom_attributes ->> 'saas_trial_ends_at') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
--    AND coalesce(custom_attributes ->> 'saas_paid_until', custom_attributes ->> 'saas_trial_ends_at')::date
--        BETWEEN current_date AND current_date + 7;

-- Contas suspensas por inadimplência (status 1 = suspended)
-- SELECT id, name, internal_attributes -> 'suspensions' -> -1 AS ultima_suspensao
--   FROM accounts WHERE status = 1 AND internal_attributes -> 'suspensions' -> -1 ->> 'category' = 'non_payment';


-- -------------------------------------------------------------------------------------
-- 6) Logo e layout da marca da conta
--    - accounts.settings.brand_display: 'logo_name' (padrão: logo em cima e nome embaixo),
--      'logo_name_inline' (logo ao lado do nome), 'logo' (só a logo) ou 'name' (só o nome).
--      Editado em Configurações > Conta > Marca.
--    - accounts.settings.brand_text_image: qual imagem fica junto do nome, 'logo' (padrão) ou
--      'collapsed_logo' (a imagem do menu fechado).
--    - Duas imagens no Active Storage (active_storage_attachments.name): 'logo' (principal) e
--      'collapsed_logo' (mostrada com a sidebar fechada; sem ela usa a principal).
--    - A logo enviada fica no Active Storage (tabelas active_storage_attachments com
--      name = 'logo' e record_type = 'Account', e active_storage_blobs). Sem logo enviada, usa
--      accounts.custom_attributes.logo (se houver) ou a logo padrão da instalação.
-- -------------------------------------------------------------------------------------
-- Exemplo: só o nome na conta 1
-- UPDATE accounts SET settings = jsonb_set(coalesce(settings, '{}'::jsonb), '{brand_display}', '"name"') WHERE id = 1;

-- Exemplo: logo ao lado do nome usando a imagem do menu fechado
-- UPDATE accounts SET settings = coalesce(settings, '{}'::jsonb) || '{"brand_display": "logo_name_inline", "brand_text_image": "collapsed_logo"}'::jsonb WHERE id = 1;

-- Contas com imagens enviadas (logo e/ou collapsed_logo)
-- SELECT a.id, a.name, att.name AS imagem, b.filename, b.byte_size
--   FROM accounts a
--   JOIN active_storage_attachments att ON att.record_type = 'Account' AND att.record_id = a.id AND att.name IN ('logo', 'collapsed_logo')
--   JOIN active_storage_blobs b ON b.id = att.blob_id;


-- -------------------------------------------------------------------------------------
-- 7) Mudanças de interface sem efeito no banco (registradas para referência)
--    - Contato: TikTok, Instagram, X (Twitter) e GitHub não aparecem mais nos formulários nem
--      na ficha do contato. Valores já salvos em contacts.additional_attributes.social_profiles
--      NÃO são apagados (apenas deixam de ser exibidos).
--    - Chat: o botão e o envio automático de assinatura de mensagem foram desativados.
-- -------------------------------------------------------------------------------------


-- -------------------------------------------------------------------------------------
-- 8) Acesso às conversas por agente em cada caixa de entrada
--    Migration: db/migrate/20261013120000_add_see_all_conversations_to_inbox_members.rb
--    Regra: um agente adicionado a uma caixa só vê as conversas atribuídas a ele ou em que é
--    participante (menção ou "adicionar participante"). Com see_all_conversations = true vê todas
--    as da caixa (supervisor). Administradores sempre veem tudo. Acesso por time não muda.
--    Valia para: lista, busca, abrir/alterar conversa, mensagens, contadores, tempo real
--    (websocket) e notificações de nova conversa.
--    Membros que já existiam foram marcados como TRUE na migration (nada muda até alguém restringir);
--    membros novos entram com FALSE (padrão da coluna).
-- -------------------------------------------------------------------------------------
ALTER TABLE inbox_members ADD COLUMN see_all_conversations boolean NOT NULL DEFAULT false;
UPDATE inbox_members SET see_all_conversations = TRUE;   -- só na migration, para quem já existia

-- Liberar o usuário 7 para ver todas as conversas da caixa 3
-- UPDATE inbox_members SET see_all_conversations = TRUE WHERE inbox_id = 3 AND user_id = 7;

-- Quem vê tudo e quem só vê as próprias, por caixa
-- SELECT i.name AS caixa, u.name AS agente, m.see_all_conversations AS ve_tudo
--   FROM inbox_members m JOIN inboxes i ON i.id = m.inbox_id JOIN users u ON u.id = m.user_id
--  ORDER BY i.name, u.name;

-- Conversas que o usuário 7 enxerga na caixa 3 quando restrito (atribuídas a ele ou participante)
-- SELECT c.display_id FROM conversations c
--  WHERE c.inbox_id = 3
--    AND (c.assignee_id = 7 OR c.id IN (SELECT conversation_id FROM conversation_participants WHERE user_id = 7));


-- -------------------------------------------------------------------------------------
-- 9) Interface sem efeito no banco (13/10)
--    - Sidebar: botão no topo abre/fecha; aberta pode ser alargada, nunca abaixo de 192 px; fechada = 56 px.
--      Preferência do usuário em users.ui_settings: sidebar_collapsed (bool) e sidebar_open_width (px).
--    - Conversas arquivadas: linha "Arquivadas" acima dos filtros abre uma tela só com elas; o número
--      ao lado é quantas arquivadas têm mensagens novas. Continua usando conversation_user_states (seção 1).
-- -------------------------------------------------------------------------------------
-- Preferências de sidebar de um usuário
-- SELECT id, ui_settings ->> 'sidebar_collapsed' AS fechada, ui_settings ->> 'sidebar_open_width' AS largura FROM users;

-- Quantas conversas arquivadas cada usuário tem
-- SELECT user_id, count(*) FROM conversation_user_states WHERE archived_at IS NOT NULL GROUP BY user_id;

-- Arquivadas com mensagem nova (o número da linha "Arquivadas": só conta as que têm mensagens não lidas)
-- SELECT s.user_id, count(*) FROM conversation_user_states s JOIN conversations c ON c.id = s.conversation_id
--  WHERE s.archived_at IS NOT NULL
--    AND EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = c.id AND m.message_type = 0
--                AND (c.agent_last_seen_at IS NULL OR m.created_at > c.agent_last_seen_at))
--  GROUP BY s.user_id;

-- -------------------------------------------------------------------------------------
-- 10) Datas nas conversas (13/10, sem efeito no banco)
--     Cada mensagem mostra só a hora (a data completa fica na dica ao passar o mouse) e um divisor
--     pequeno marca o primeiro dia de mensagens: "Hoje", "Ontem", o dia da semana nos últimos 7 dias
--     ou a data (dd/mm/aaaa em pt-BR). Usa messages.created_at, sem coluna nova.
-- -------------------------------------------------------------------------------------

-- -------------------------------------------------------------------------------------
-- 11) Painel do contato e busca na conversa (14/10, sem efeito no banco)
--     - O painel do contato abre ao clicar no nome/foto no topo da conversa (não há mais o botão na lateral
--       direita). Continua usando users.ui_settings.is_contact_sidebar_open.
--     - Busca na conversa: o texto procurado fica destacado nas mensagens encontradas e a rolagem vai
--       sozinha para a mais recente. Busca em messages.content (ILIKE), sem coluna nova.
-- -------------------------------------------------------------------------------------


-- -------------------------------------------------------------------------------------
-- 2026-10-14) Rodizio por agente e time padrao da caixa de entrada
--    Migrations: db/migrate/20261014100000_add_in_rotation_to_inbox_members.rb
--                db/migrate/20261014100100_add_default_team_to_inboxes.rb
--    inbox_members.in_rotation: false = o agente tem acesso a caixa mas a atribuicao automatica nunca o escolhe
--      (atribuicao manual continua valendo). Todo membro existente entra com TRUE: nada muda ate alguem desmarcar.
--    inboxes.default_team_id: toda conversa NOVA da caixa nasce com esse time (se quem criou nao escolheu outro);
--      a atribuicao automatica passa a considerar so os membros do time. Time apagado = coluna volta a NULL.
-- -------------------------------------------------------------------------------------
ALTER TABLE inbox_members ADD COLUMN in_rotation boolean NOT NULL DEFAULT true;
ALTER TABLE inboxes       ADD COLUMN default_team_id bigint;
CREATE INDEX index_inboxes_on_default_team_id ON inboxes (default_team_id);

-- Tirar um agente do rodizio de uma caixa (troque os ids)
-- UPDATE inbox_members SET in_rotation = false WHERE inbox_id = 3 AND user_id = 7;

-- Definir o time padrao de uma caixa
-- UPDATE inboxes SET default_team_id = 2 WHERE id = 3;

-- Quem esta no rodizio de cada caixa
-- SELECT i.name AS caixa, u.name AS agente, m.in_rotation
--   FROM inbox_members m JOIN inboxes i ON i.id = m.inbox_id JOIN users u ON u.id = m.user_id
--  ORDER BY i.name, u.name;


-- -------------------------------------------------------------------------------------
-- 2026-10-15) Integracoes (Dashboard Apps) por caixa de entrada
--    Migration: db/migrate/20261015120000_add_inbox_ids_to_dashboard_apps.rb
--    dashboard_apps.inbox_ids: caixas cujas conversas mostram o app. Vazio = aparece em todas (comportamento antigo),
--      entao todo app existente continua aparecendo em todas as caixas ate alguem escolher.
-- -------------------------------------------------------------------------------------
ALTER TABLE dashboard_apps ADD COLUMN inbox_ids bigint[] NOT NULL DEFAULT '{}';

-- Mostrar um app so em algumas caixas (troque os ids)
-- UPDATE dashboard_apps SET inbox_ids = '{3,6}' WHERE id = 1;

-- Onde cada app aparece
-- SELECT d.title, CASE WHEN cardinality(d.inbox_ids) = 0 THEN 'todas' ELSE array_to_string(d.inbox_ids, ',') END AS caixas
--   FROM dashboard_apps d ORDER BY d.title;


-- -------------------------------------------------------------------------------------
-- 2026-10-20) Modo Vendedor
--    Sem migration: chave jsonb accounts.settings.seller_mode (boolean).
--    Ausente ou true = agentes veem a versao simples (padrao). false = agentes veem tudo, como o Chatwoot original.
--    Administradores sempre veem tudo. Lista do que fica escondido: docs/FUNCOES_ESCONDIDAS.md.
--    Mudanca de permissao no mesmo dia (sem banco): agente so exclui as proprias mensagens; mesclar contatos e
--    editar/excluir respostas prontas ficaram so para administrador.
-- -------------------------------------------------------------------------------------
-- Desligar o Modo Vendedor de uma conta (troque o id)
-- UPDATE accounts SET settings = jsonb_set(coalesce(settings, '{}'::jsonb), '{seller_mode}', 'false') WHERE id = 1;

-- Ver quais contas estao com o modo desligado
-- SELECT id, name FROM accounts WHERE settings->>'seller_mode' = 'false';


-- -------------------------------------------------------------------------------------
-- 2026-10-20) RESUMO PARA A MIGRACAO DA PRODUCAO
--    Na troca, o pre-deploy roda "bundle exec rails db:migrate": as migracoes abaixo (do fork) rodam junto com
--    as do Chatwoot oficial que a producao ainda nao tem (a producao esta na imagem de 30/07). Todas sao so de
--    adicao (colunas/tabelas novas com valor padrao), nenhuma apaga dado. Fonte de verdade: db/migrate.
--
--    Migracoes do fork, em ordem:
--      20261012120000  create_conversation_user_states        (fixar/arquivar por usuario)
--      20261013120000  add_see_all_conversations_to_inbox_members (membros existentes ficam TRUE = nada muda)
--      20261014100000  add_in_rotation_to_inbox_members       (todos ficam no rodizio = nada muda)
--      20261014100100  add_default_team_to_inboxes            (vazio = nada muda)
--      20261015120000  add_inbox_ids_to_dashboard_apps        (vazio = app aparece em todas as caixas, como hoje)
--      20261020204252  add_ai_only_to_articles                (false = artigos continuam publicos)
--
--    Convencoes jsonb (sem migracao), que ja valem no primeiro acesso:
--      accounts.settings.seller_mode   ausente = Modo Vendedor LIGADO para os agentes (os vendedores ja entram
--                                      na versao simples). Para desligar: ver secao Modo Vendedor acima.
--      accounts.settings.brand_display / brand_text_image, accounts.custom_attributes.saas_*,
--      channel_whatsapp.provider_config (webhook_secret, call_permission_template, send_read_receipts,
--      calling_enabled, inbound_calls_enabled), messages.content_attributes.reactions.
--
--    Conferencias depois do deploy (somente leitura):
-- SELECT version FROM schema_migrations WHERE version >= '20261012000000' ORDER BY version;  -- deve listar as 6 acima
-- SELECT count(*) FROM inbox_members WHERE see_all_conversations = false;                  -- deve ser 0 logo apos a troca
-- SELECT count(*) FROM inbox_members WHERE in_rotation = false;                            -- deve ser 0 logo apos a troca
-- SELECT count(*) FROM articles WHERE ai_only;                                            -- deve ser 0 logo apos a troca


-- -------------------------------------------------------------------------------------
-- 2026-10-20) Artigos "Exclusivo para IA" na Central de Ajuda
--    Migration: db/migrate/20261020204252_add_ai_only_to_articles.rb
--    Regra: artigo com ai_only = true continua sendo lido pelo Captain/Copilot, mas NAO aparece no site publico
--    (lista, categorias, busca, sitemap, link direto = 404), nem na busca de "inserir artigo" na resposta, nem para
--    os vendedores no painel. So administradores (e funcao personalizada knowledge_base_manage) veem, com o selo
--    "Exclusivo para IA", e marcam/desmarcam em Propriedades do artigo.
--    Mudanca de permissao no mesmo dia (sem banco): vendedores (agentes) podem LER a Central de Ajuda no painel.
-- -------------------------------------------------------------------------------------
ALTER TABLE articles ADD COLUMN ai_only boolean DEFAULT false NOT NULL;

-- Marcar um artigo como exclusivo para a IA (troque o id)
-- UPDATE articles SET ai_only = true, updated_at = now() WHERE id = 42;

-- Listar os artigos exclusivos para a IA
-- SELECT id, account_id, portal_id, title, status FROM articles WHERE ai_only ORDER BY account_id, portal_id, id;

-- 2026-10-21  botoes dos modelos do WhatsApp aparecem na bolha (sem alteracao de banco: le messages.additional_attributes.template_params
--             e os botoes dos modelos sincronizados da caixa, channel_whatsapp.message_templates)
-- 2026-10-21  login, titulo da aba e favicon usam a marca da conta com logo (sem alteracao de banco: le o logo, o
--             collapsed_logo e accounts.settings.brand_display; so onde o Super Admin ainda esta no padrao do Chatwoot)

-- 2026-10-21  perfis de automacao (sem alteracao de banco: robo da conta em agent_bots com outgoing_url vazio; o token fica em access_tokens)

-- -------------------------------------------------------------------------------------
-- 2026-10-22) Transcricao de audio com Whisper proprio (sem Captain)
--    Sem migration: 4 linhas em installation_configs, editaveis no Super Admin > Transcricao de audio.
--    Com AUDIO_TRANSCRIPTION_API_URL preenchido, audios e gravacoes de ligacao vao para esse servidor (compativel com a
--    API da OpenAI); nao exige Captain nem gasta credito. Por conta, liga em Configuracoes > Conta (accounts.settings.audio_transcriptions).
--    A transcricao fica em attachments.meta->>'transcribed_text'. Fila: medium (antes low).
-- -------------------------------------------------------------------------------------
-- SELECT name, serialized_value #>> '{}' AS valor FROM installation_configs WHERE name LIKE 'AUDIO_TRANSCRIPTION_%' AND name <> 'AUDIO_TRANSCRIPTION_API_KEY';
-- Ultimas transcricoes:
-- SELECT a.id, a.message_id, left(a.meta->>'transcribed_text', 80) FROM attachments a WHERE a.file_type = 1 AND a.meta ? 'transcribed_text' ORDER BY a.id DESC LIMIT 20;
