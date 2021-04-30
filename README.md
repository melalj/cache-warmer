# cache-warmer

Docker image to warm up and preload cloudflare cache

Warm the caches of your website by crawling each page defined in a sitemapindex

```bash
./cache-warmer.py --url https://example.com/sitemap.xml
```

```bash
docker run -ti melalj/cache-warmer ./cache-warmer.py --url https://example.com/sitemap.xml

```

Credits [@hn-support gist](https://gist.github.com/hn-support/bc7cc401e3603a848a4dec4b18f3a78d)
