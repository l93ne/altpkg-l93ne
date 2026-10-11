Name: hello-l93ne
Version: 1.0
Release: alt1
Summary: Shell script that prints the author, group and lab number
License: GPL-3.0-or-later
Group: Development/Other
BuildArch: noarch
Source0: %name-%version.sh

%description
A one-line shell script packaged to study automatically computed dependencies.

%install
install -D -m 755 %SOURCE0 %buildroot%_bindir/%name

%files
%_bindir/%name

%changelog
* Sun Oct 11 2026 l93ne <149338526+l93ne@users.noreply.github.com> 1.0-alt1
- Initial build.
