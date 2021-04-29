# cache-warmer

Docker image to warm up and preload cloudflare cache

```bash
bash ./entrypoint.sh -v "https://example.com/sitemap.xml" -r
```

```bash
docker run -ti melalj/cache-warmer bash ./entrypoint.sh -v "https://refurbme-images.s3.amazonaws.com/warmup.xml" -r

```

Credits [@CodeEgg gist](https://gist.github.com/Code-Egg/188dd65ec4c69f517c50a66bedeb759d)
