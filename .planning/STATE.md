# NovelOS HZ Deployment State

## Goal

Run NovelOS locally while HZ cloud deployment is blocked, with the macOS app temporarily pointed at `http://127.0.0.1:7773`.

## Completed

- Read `/Users/linotsai/HZ云使用手册.md`.
- Switched production domain references from `write.neluvee.top` to `write.linotsai.top`.
- Backend production config and app source were prepared locally.
- Local backend tests passed with `.venv/bin/pytest`: 13 passed.
- Local Swift tests passed after the domain switch: 18 passed.
- Repackaged macOS app: `/Users/linotsai/Lino/LinoWriting/NovelOSMac/dist/NovelOSMac.app`.
- Synced `NovelOSBackend` and the ignored production `.env` to HZ:
  - Remote app dir: `/home/deploy/novelos`
  - Remote env: `/home/deploy/novelos/deploy/.env`
- Switched macOS default backend URL to `http://127.0.0.1:7773`.
- Wrote the current macOS user default `com.lino.novelosmac NovelOSBackendURL` to `http://127.0.0.1:7773`.
- Started local backend as LaunchAgent `top.linotsai.novelos.local7773`.
- Verified local backend:
  - `GET http://127.0.0.1:7773/healthz`
  - `GET http://127.0.0.1:7773/api/novels`
- Repackaged macOS app after local URL switch.

## Current Blocker

- `docker compose -f docker-compose.prod.yml up -d --build` on HZ failed while pulling `postgres:16-alpine` from Docker Hub due to network timeout.
- After attempting `sudo systemctl restart docker`, SSH to `deploy@118.178.122.194` began timing out during banner exchange.
- Public homepage health (`https://linotsai.top/health`) still returned `ok`, so the host is at least partially reachable; SSH is the active blocker.
- This cloud blocker is parked for now; local service is the active route.

## Next Action

For local work, use:

```bash
curl -fsS http://127.0.0.1:7773/healthz
launchctl print gui/$(id -u)/top.linotsai.novelos.local7773
```

To stop the local service:

```bash
launchctl bootout gui/$(id -u) top.linotsai.novelos.local7773
```

When returning to cloud, first check when SSH recovers:

```bash
ssh -o ConnectTimeout=20 deploy@118.178.122.194 'hostname && uptime && systemctl is-active docker || true'
```

Then continue:

1. Restore Docker responsiveness.
2. Configure a usable image mirror or otherwise make Postgres/API image pulls reliable.
3. Run `/home/deploy/novelos/deploy/docker-compose.prod.yml`.
4. Install Nginx site for `write.linotsai.top`, issue/reuse the certificate, test, and reload.
5. Verify `https://write.linotsai.top/healthz` and token-protected API calls.

## Notes

- Do not print `.env` or owner token contents.
- Do not local ping the new domain; DNS was already configured by the user.
