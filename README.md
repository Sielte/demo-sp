Script per creare un SP compatibile con SPID
==================

In questo repository è presente uno script per creare un SP (Service Provider) compatibile con SPID.


Requisiti
--------
Lo script è stato progettato per essere eseguito su una Ubuntu 14.04.


Utilizzo
--------
Scaricare lo script sulla VM e eseguirlo con bash.
```bash
chmod +x /opt/create-newsp.sh
./opt/create-newsp.sh
```

Risultato
--------

Il percorso di installazione finale è ```/opt/spid-simplesamlphp```.
Tramite il browser è possibile accedere https://localhost/simplesaml

