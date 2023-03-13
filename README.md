# qs-deploy

<p align="center">
  <img src="https://github.com/qsocket/qs-deploy/raw/master/.github/img/banner.png">
  <br>
  <a href="https://github.com/qsocket/qs-deploy/actions/workflows/main.yml">
    <img src="https://github.com/qsocket/qs-netcat/actions/workflows/main.yml/badge.svg">
  </a>
  <a href="https://github.com/qsocket/qs-deploy/issues">
    <img src="https://img.shields.io/github/issues/qsocket/qs-deploy?style=flat-square&color=red">
  </a>
  <a href="https://raw.githubusercontent.com/qsocket/qs-deploy/master/LICENSE">
    <img src="https://img.shields.io/github/license/qsocket/qs-deploy.svg?style=flat-square">
  </a>
</p> 

#### For Unix-like systems `(almost any OS with a bash)`
```bash
bash -c "$(curl -fsSL qsocket.io/0)"
```

#### For Windows
```powershell
IEX(New-Object Net.WebClient).downloadString('https://qsocket.io/1')
```

#### For Android `(no-root devices)`
1. Enable USB debugging on the android devive.
2. Attach the android device to a linux host with adb installed.
3. Run the following command on the linux host... 
```bash
bash -c "$(curl -fsSL qsocket.io/2)"
```