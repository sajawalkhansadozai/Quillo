# Quillo — GitHub Pages (legal site)

Static site for Privacy Policy and Terms & Conditions, deployed via [GitHub Pages](https://docs.github.com/en/pages).

## Pages

| URL path | File |
|----------|------|
| `/` | `index.html` |
| `/privacy/` | `privacy/index.html` |
| `/terms/` | `terms/index.html` |

## Enable GitHub Pages

1. Push this repo to GitHub.
2. Open **Settings → Pages**.
3. Under **Build and deployment → Source**, choose **Deploy from a branch**.
4. Branch: **main** (or your default branch).
5. Folder: **`/docs`**.
6. Save. After a few minutes the site is live at:
   `https://<username>.github.io/<repo-name>/`

## Custom domain (`quillo.app`)

To match the app links (`https://quillo.app/privacy`, `https://quillo.app/terms`):

1. In **Settings → Pages → Custom domain**, enter `quillo.app`.
2. Add a `CNAME` file in `docs/` (only if GitHub does not create it automatically):

   ```
   quillo.app
   ```

3. At your DNS provider, add:
   - **A** records → GitHub Pages IPs (see [GitHub docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain)), or
   - **CNAME** `www` → `<username>.github.io` (if using `www.quillo.app`)

4. Enable **Enforce HTTPS** in GitHub Pages settings.

## Updating content

Legal text source of truth is also in `/legal/*.md` (used by the Flutter app). When you change policy text:

1. Edit `legal/privacy_policy.md` and/or `legal/terms_and_conditions.md`.
2. Update the matching HTML in `docs/privacy/index.html` and `docs/terms/index.html`.
3. Commit and push — Pages redeploys automatically.

## Local preview

```bash
cd docs
python3 -m http.server 8080
```

Open http://localhost:8080/privacy/ and http://localhost:8080/terms/
