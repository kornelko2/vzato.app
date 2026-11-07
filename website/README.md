# vzato.app website

Static marketing page and privacy policy. Plain HTML and CSS, no build step, no JavaScript,
no external requests, no cookies. Each page carries all four languages (cs, sk, en, hu);
`#cs`, `#sk`, `#en`, `#hu` in the URL select one, Czech is the default.

- `index.html` – landing page
- `privacy.html` – privacy policy (App Store Connect "Privacy Policy URL" points here)
- `style.css`, `img/` – the icon comes from `Design/icon/E-pulena-tableta-fajfka.svg`;
  `img/<lang>/` holds the screenshots per language (iPhone simulator, debug launch argument
  `--sample-data`)

Preview locally:

```bash
open website/index.html
```

Publish by serving this folder as the site root (GitHub Pages from `/website`, Cloudflare Pages,
or any static host). Keep the privacy policy in sync with the app: it must stay true.
