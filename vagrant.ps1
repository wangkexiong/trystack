$_before=$pwd
mkdir C:\Users\appveyor\.vagrant.d | Out-Null
mkdir C:\downloads | Out-Null
cd C:\downloads
Start-FileDownload "https://releases.hashicorp.com/vagrant/1.8.1/vagrant_1.8.1.msi"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/a vagrant_1.8.1.msi /qb TARGETDIR=C:\Vagrant" -Wait
Start-FileDownload "http://download.virtualbox.org/virtualbox/5.0.14/VirtualBox-5.0.14-105127-Win.exe"
Start-Process -FilePath "VirtualBox-5.0.14-105127-Win.exe" -ArgumentList "-silent -logging -msiparams INSTALLDIR=C:\VBox" -Wait
cd $_before.Path
$ENV:Path="C:\Vagrant\HashiCorp\Vagrant\bin;C:\VBox;"+$ENV:Path
