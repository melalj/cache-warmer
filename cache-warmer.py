#!/usr/bin/env python
"""
Warm the caches of your website by crawling each page defined in sitemap.xml.
To use, download this file and make it executable. Then run:
./cache-warmer.py --url https://example.com/sitemap.xml
"""
import argparse
import re
import requests
import asyncio
import aiohttp
import time

def parse_options():
    parser = argparse.ArgumentParser(description="""Cache crawler""")
    parser.add_argument('-u', '--url', help='The sitemap xml url', required=True, type=str)

    args = parser.parse_args()
    return args

def get_sitemap_urls(url):
    a = requests.get(url, headers={"user-agent": "cache_warmer"})
    return re.findall('<loc>(.*?)</loc>?', a.text)

def get_url_list(url):
    a = requests.get(url, headers={"user-agent": "cache_warmer"})
    return re.findall('<loc>(.*?)</loc>?', a.text)


async def get(url, session):
    try:
        async with session.get(url=url) as response:
            resp = await response.read()
            print(f"{url} -> {response.status} {response.headers['CF-Cache-Status']}")
    except Exception as e:
        print(f"{url} -> {str(e)}")



async def warmup(urls):
    async with aiohttp.ClientSession(headers={"user-agent": "cache_warmer"}) as session:
        ret = await asyncio.gather(*[get(url, session) for url in urls])
    print(f"Warmed up {len(ret)} URLS")

def main():
    args = parse_options()
    sitemap_urls = get_sitemap_urls(args.url)

    for sitemap_url in sitemap_urls:
        url_list = get_url_list(sitemap_url)

        print(f"{sitemap_url}\nCrawling {len(url_list)} urls...")

        start = time.time()
        asyncio.run(warmup(url_list))
        end = time.time()

    sys.exit()


if __name__ == "__main__":
    main()