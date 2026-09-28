# OpenLinkArchitect

**Open-source AI-powered link outreach & prospecting tool.**

Focused on high-quality, safe methods (guest posts, editorial links, resource pages).  
Self-hosted with Docker. No spammy automation.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/open-link-architect/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/YOUR_ORG/open-link-architect.git
cd open-link-architect
cp .env.example .env
# Edit .env and add your OpenAI or Anthropic key
docker compose up -d --build
```

Open → [http://localhost:3000](http://localhost:3000)

## Features (MVP Skeleton)

- Campaign management
- Prospect tracking
- Email drafting structure
- PostgreSQL + Prisma
- Health check endpoint
- One-command Docker setup
- Install script with interactive configuration

## Tech Stack

- Next.js 15 (App Router)
- TypeScript
- Prisma + PostgreSQL
- Tailwind CSS
- Docker Compose

## Development

```bash
npm install
npx prisma db push
npm run dev
```

## License

MIT

## Disclaimer

This tool is designed for ethical, white-hat outreach only.  
Do not use it for spam, automated low-quality link building, or any activity that violates search engine guidelines.
