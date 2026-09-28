import {
  Activity,
  ArrowDownRight,
  ArrowUpRight,
  Bell,
  Blocks,
  Bot,
  BriefcaseBusiness,
  ChartNoAxesCombined,
  ChevronDown,
  CircleHelp,
  Command,
  CreditCard,
  LayoutDashboard,
  Plus,
  Search,
  Sparkles,
  Settings2,
  UsersRound,
} from "lucide-react";

const navigation = [
  { label: "Visão geral", icon: LayoutDashboard, active: true },
  { label: "Projetos", icon: BriefcaseBusiness },
  { label: "Pessoas", icon: UsersRound },
  { label: "Financeiro", icon: CreditCard },
  { label: "Analytics", icon: ChartNoAxesCombined },
  { label: "Inteligência artificial", icon: Bot },
];

const metrics = [
  { label: "Projetos ativos", value: "0", change: "Nenhum projeto criado", icon: BriefcaseBusiness, tone: "mint" },
  { label: "Tarefas em andamento", value: "0", change: "Tudo em dia", icon: Activity, tone: "blue" },
  { label: "Pessoas no workspace", value: "0", change: "Convide seu time", icon: UsersRound, tone: "coral" },
  { label: "Despesas no período", value: "R$ 0", change: "Sem lançamentos", icon: CreditCard, tone: "amber" },
];

export default function DashboardPage() {
  return (
    <div className="app-frame">
      <aside className="sidebar">
        <a className="brand" href="#inicio" aria-label="NEXUS ONE início">
          <span className="brand-mark"><Blocks size={19} strokeWidth={2.3} /></span>
          <span>NEXUS<span className="brand-light">ONE</span></span>
        </a>

        <button className="workspace-switcher" type="button">
          <span className="workspace-avatar">N</span>
          <span className="workspace-copy"><strong>Seu workspace</strong><small>Plano de avaliação</small></span>
          <ChevronDown size={15} />
        </button>

        <div className="nav-label">WORKSPACE</div>
        <nav className="primary-nav" aria-label="Navegação principal">
          {navigation.map(({ label, icon: Icon, active }) => (
            <a key={label} className={`nav-item${active ? " active" : ""}`} href={active ? "#inicio" : "#modulos"} aria-current={active ? "page" : undefined}>
              <Icon size={17} strokeWidth={1.8} />
              <span>{label}</span>
              {label === "Inteligência artificial" && <span className="nav-new">IA</span>}
            </a>
          ))}
        </nav>

        <div className="nav-label nav-label-spaced">PREFERÊNCIAS</div>
        <nav className="primary-nav" aria-label="Preferências">
          <a className="nav-item" href="#modulos"><Settings2 size={17} strokeWidth={1.8} /><span>Configurações</span></a>
          <a className="nav-item" href="#ajuda"><CircleHelp size={17} strokeWidth={1.8} /><span>Central de ajuda</span></a>
        </nav>

        <div className="sidebar-bottom">
          <div className="plan-meter"><div className="plan-meter-head"><span>Seu espaço</span><span>0%</span></div><div className="meter-track"><span /></div><small>Configure o workspace para começar</small></div>
          <button className="profile-button" type="button">
            <span className="profile-avatar">N</span>
            <span className="profile-copy"><strong>Administrador</strong><small>Conta de workspace</small></span>
            <ChevronDown size={14} />
          </button>
        </div>
      </aside>

      <main className="main-area" id="inicio">
        <header className="topbar">
          <div className="breadcrumb"><span>Workspace</span><span className="breadcrumb-slash">/</span><strong>Visão geral</strong></div>
          <div className="topbar-actions">
            <button className="search-trigger" type="button" aria-label="Pesquisar"><Search size={15} /><span>Pesquisar</span><kbd><Command size={11} /> K</kbd></button>
            <button className="icon-button notification-button" type="button" aria-label="Notificações"><Bell size={18} /><i /></button>
            <span className="topbar-divider" />
            <span className="topbar-date">Ambiente de avaliação</span>
          </div>
        </header>

        <div className="page-content">
          <section className="welcome-row">
            <div>
              <div className="eyebrow"><span className="eyebrow-dot" /> SEU ESPAÇO DE TRABALHO</div>
              <h1>Seu workspace <span>em perspectiva.</span></h1>
              <p>Uma visão clara do que importa para o seu time.</p>
            </div>
            <button className="button-primary" type="button"><Plus size={17} /> Criar projeto</button>
          </section>

          <section className="metric-grid" aria-label="Indicadores do workspace">
            {metrics.map(({ label, value, change, icon: Icon, tone }) => (
              <article className="metric-card" key={label}>
                <div className="metric-top"><span>{label}</span><span className={`metric-icon ${tone}`}><Icon size={17} strokeWidth={1.8} /></span></div>
                <div className="metric-value">{value}</div>
                <div className="metric-change"><span>{change}</span><ArrowDownRight size={14} /></div>
              </article>
            ))}
          </section>

          <section className="content-grid">
            <article className="panel projects-panel">
              <div className="panel-heading"><div><h2>Projetos</h2><p>Acompanhe as iniciativas do seu time</p></div><button className="text-action" type="button">Ver todos <ArrowUpRight size={14} /></button></div>
              <div className="empty-state">
                <div className="empty-illustration"><BriefcaseBusiness size={23} strokeWidth={1.5} /><span><Plus size={12} /></span></div>
                <h3>Seu primeiro projeto começa aqui</h3>
                <p>Organize iniciativas, defina responsáveis e acompanhe cada entrega em um só lugar.</p>
                <button className="button-secondary" type="button"><Plus size={15} /> Novo projeto</button>
              </div>
            </article>

            <article className="panel activity-panel">
              <div className="panel-heading"><div><h2>Atividade recente</h2><p>Atualizações do workspace</p></div><button className="icon-button small" type="button" aria-label="Opções de atividade"><Settings2 size={16} /></button></div>
              <div className="activity-empty"><span className="activity-line" /><span className="activity-icon"><Activity size={16} /></span><div><strong>Nenhuma atividade ainda</strong><p>Quando algo acontecer, aparece por aqui.</p></div></div>
              <div className="activity-footer"><span className="activity-status" /> Aguardando configuração do workspace</div>
            </article>
          </section>

          <section className="bottom-banner" id="modulos">
            <div className="banner-copy"><span className="banner-kicker"><Bot size={14} /> NEXUS INTELLIGENCE</span><h2>Seu trabalho, com mais contexto.</h2><p>Conecte seus dados e prepare seu workspace para insights assistidos por IA.</p></div>
            <button className="banner-button" type="button">Explorar inteligência <ArrowUpRight size={15} /></button>
            <span className="banner-spark spark-one"><Sparkles size={14} /></span><span className="banner-spark spark-two"><Sparkles size={11} /></span>
          </section>

          <footer className="page-footer"><span>NEXUS ONE <span className="footer-dot">·</span> Workspace empresarial</span><span>Ambiente não conectado a dados de produção</span></footer>
        </div>
      </main>
    </div>
  );
}