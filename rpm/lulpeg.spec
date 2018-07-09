Name: lulpeg
Version: 0.1.1
Release: 1%{?dist}
Summary: LuLPeg
Group: Applications/Databases
License: The Romantic WTF public license
URL: https://github.com/tarantool/LuLPeg
Source0: lulpeg-%{version}.tar.gz
BuildArch: noarch

BuildRequires: tarantool >= 1.7.5.0
Requires: tarantool >= 1.7.5.0

%description
LuLPeg, a pure Lua port of LPeg, Roberto Ierusalimschy's Parsing Expression
Grammars library. Copyright (C) Pierre-Yves Gerardy.

%prep
%setup -q -n lulpeg-%{version}

%build
cd src
tarantool -e 'require("strict").off()' ../scripts/pack.lua > ../lulpeg.lua

%install
mkdir -p %{buildroot}%{_datadir}/tarantool/lulpeg
cp -R . %{buildroot}%{_datadir}/tarantool/lulpeg/

%files
%dir %{_datadir}/tarantool/lulpeg
%{_datadir}/tarantool/lulpeg/
