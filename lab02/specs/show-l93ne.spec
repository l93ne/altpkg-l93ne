Name: show-l93ne
Version: 1.0
Release: alt1
Summary: Simple page-by-page text file viewer based on ncurses
License: GPL-3.0-or-later
Group: Text tools
Source: %name-%version.tar.gz

BuildRequires: libncurses-devel

%description
Show displays a text file page by page in a terminal window.
Space scrolls one page forward, q quits.

%prep
%setup

%build
%make_build CFLAGS="%optflags"

%install
install -D -m 755 Show %buildroot%_bindir/Show

%files
%_bindir/Show

%changelog
* Sun Oct 11 2026 l93ne <l93ne@altlinux.org> 1.0-alt1
- Initial build.
