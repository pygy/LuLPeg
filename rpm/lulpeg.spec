Name: lulpeg
# During package building {version} is overwritten by Packpack with
# VERSION. It is set to major.minor.number_of_commits_above_last_tag.
# major.minor tag and number of commits above are taken from the
# github repository: https://github.com/tarantool/LuLPeg
Version: 0.1
Release: 1%{?dist}
Summary: LuLPeg
Group: Applications/Databases
License: The Romantic WTF public license
URL: https://github.com/tarantool/LuLPeg
Source0: lulpeg-%{version}.tar.gz
BuildArch: noarch

BuildRequires: tarantool >= 1.9.0.0
Requires: tarantool >= 1.9.0.0

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
cp ./src/* %{buildroot}%{_datadir}/tarantool/lulpeg/
mv lulpeg.lua %{buildroot}%{_datadir}/tarantool/lulpeg/

%files
%dir %{_datadir}/tarantool/lulpeg
%{_datadir}/tarantool/lulpeg/

%changelog

* Tue Jul 10 2018 Ivan Koptelov <ivan.koptelov@tarantool.org> 0.1-1
- Initial packaging
