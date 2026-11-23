"""Convierte las imagenes del PM en assets/agentes/<clave>/<estado>.webp con fondo transparente."""
import sys, os, glob
from collections import deque
from PIL import Image, ImageFilter
SRC, DST = sys.argv[1], sys.argv[2]
MAPA = {'saludando': 'saludo', 'escuchando': 'escuchando', 'pensando': 'pensando',
        'hablando': 'hablando', 'alerta': 'alerta', 'despedida': 'despedida'}
LADO = 512
def procesar(ruta, salida):
    im = Image.open(ruta).convert('RGBA')
    # trabajo a escala reducida para el fondo
    w, h = im.size
    esc = 4
    sm = im.resize((w // esc, h // esc)).convert('RGB')
    sw, sh = sm.size
    px = sm.load()
    # marca de agua abajo a la derecha: pintarla de fondo
    fondo = px[3, 3]
    for x in range(int(sw * 0.86), sw):
        for y in range(int(sh * 0.86), sh):
            px[x, y] = fondo
    def es_fondo(c):
        return max(abs(c[0]-fondo[0]), abs(c[1]-fondo[1]), abs(c[2]-fondo[2])) <= 14 and max(c)-min(c) <= 10
    vis = bytearray(sw * sh)
    q = deque()
    for x in range(sw):
        q.append((x, 0)); q.append((x, sh-1))
    for y in range(sh):
        q.append((0, y)); q.append((sw-1, y))
    while q:
        x, y = q.popleft()
        i = y * sw + x
        if vis[i] or not es_fondo(px[x, y]):
            continue
        vis[i] = 1
        if x > 0: q.append((x-1, y))
        if x < sw-1: q.append((x+1, y))
        if y > 0: q.append((x, y-1))
        if y < sh-1: q.append((x, y+1))
    mask = Image.new('L', (sw, sh), 0)
    mp = mask.load()
    for y in range(sh):
        for x in range(sw):
            mp[x, y] = 0 if vis[y*sw+x] else 255
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    mask = mask.resize((w, h), Image.LANCZOS)
    im.putalpha(mask)
    caja = mask.point(lambda v: 255 if v > 40 else 0).getbbox()
    im = im.crop(caja)
    cw, ch = im.size
    lado = max(cw, ch)
    lienzo = Image.new('RGBA', (lado, lado), (0, 0, 0, 0))
    lienzo.paste(im, ((lado - cw) // 2, lado - ch))  # apoyado abajo
    lienzo = lienzo.resize((LADO, LADO), Image.LANCZOS)
    os.makedirs(os.path.dirname(salida), exist_ok=True)
    lienzo.save(salida, 'WEBP', quality=88, method=6)
    return caja
for clave in ('kuntur', 'quirqui', 'faustino'):
    for f in sorted(glob.glob(os.path.join(SRC, clave, '*.png'))):
        nombre = os.path.splitext(os.path.basename(f))[0]
        partes = nombre.split(' ', 1)
        estado = MAPA.get(partes[1]) if len(partes) == 2 else 'base'
        if not estado:
            print('sin estado', f); continue
        caja = procesar(f, os.path.join(DST, clave, estado + '.webp'))
        print(clave, estado, caja)
