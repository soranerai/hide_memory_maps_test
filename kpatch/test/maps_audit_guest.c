/* SPDX-License-Identifier: GPL-2.0 */
/* Freestanding ARM64 guest test: create VMAs and read /proc/self/maps. */
#define AT_FDCWD (-100)
#define PROT_READ 0x1
#define PROT_WRITE 0x2
#define MAP_SHARED 0x01
#define MAP_PRIVATE 0x02
#define MAP_ANONYMOUS 0x20
#ifndef MEMHIDE_TEST_UID
#define MEMHIDE_TEST_UID 10001
#endif
#ifndef MEMHIDE_EXPECT_HIDDEN
#define MEMHIDE_EXPECT_HIDDEN 1
#endif

static long syscall6(long number, long a0, long a1, long a2, long a3,
		     long a4, long a5)
{
	register long x0 __asm__("x0") = a0;
	register long x1 __asm__("x1") = a1;
	register long x2 __asm__("x2") = a2;
	register long x3 __asm__("x3") = a3;
	register long x4 __asm__("x4") = a4;
	register long x5 __asm__("x5") = a5;
	register long x8 __asm__("x8") = number;

	__asm__ volatile("svc #0"
		: "+r"(x0)
		: "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5), "r"(x8)
		: "memory");
	return x0;
}

static long write_all(int fd, const char *buf, long len)
{
	return syscall6(64, fd, (long)buf, len, 0, 0, 0);
}

static int hex_value(char c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	return -1;
}

static int maps_contains(const char *buf, long len, unsigned long address)
{
	long i = 0;

	while (i < len) {
		unsigned long start = 0, end = 0;
		int digit, have_start = 0, have_end = 0;

		while (i < len && (digit = hex_value(buf[i])) >= 0) {
			start = (start << 4) | (unsigned long)digit;
			have_start = 1;
			i++;
		}
		if (have_start && i < len && buf[i] == '-') {
			i++;
			while (i < len && (digit = hex_value(buf[i])) >= 0) {
				end = (end << 4) | (unsigned long)digit;
				have_end = 1;
				i++;
			}
			if (have_end && address >= start && address < end)
				return 1;
		}
		while (i < len && buf[i++] != '\n')
			;
	}
	return 0;
}

static long read_maps(char *buffer, long capacity)
{
	static const char maps_path[] = "/proc/self/maps";
	long fd, bytes, total = 0;

	fd = syscall6(56, AT_FDCWD, (long)maps_path, 0, 0, 0, 0);
	if (fd < 0)
		return fd;
	while (total < capacity) {
		bytes = syscall6(63, fd, (long)(buffer + total),
				 capacity - total, 0, 0, 0);
		if (bytes <= 0)
			break;
		total += bytes;
	}
	syscall6(57, fd, 0, 0, 0, 0, 0);
	return bytes < 0 ? bytes : total;
}

void _start(void)
{
#if MEMHIDE_EXPECT_HIDDEN
	static const char pass[] = "MAPS_HIDE_GUEST=PASS uid=10001 anonymous-hidden\n";
#else
	static const char pass[] = "MAPS_HIDE_GUEST=PASS uid=10000 boundary-visible\n";
#endif
	static const char fail_root[] = "MAPS_HIDE_GUEST=FAIL root-control\n";
	static const char fail_setuid[] = "MAPS_HIDE_GUEST=FAIL setuid\n";
	static const char fail_policy[] = "MAPS_HIDE_GUEST=FAIL uid-policy\n";
	static char buffer[8192];
	volatile char *anon_private_touched;
	volatile char *anon_private_untouched;
	volatile char *anon_shared;
	long bytes;

	anon_private_touched = (void *)syscall6(222, 0, 4096,
						 PROT_READ | PROT_WRITE,
						 MAP_PRIVATE | MAP_ANONYMOUS,
						 -1, 0);
	anon_private_untouched = (void *)syscall6(222, 0, 4096,
						   PROT_READ,
						   MAP_PRIVATE | MAP_ANONYMOUS,
						   -1, 0);
	anon_shared = (void *)syscall6(222, 0, 4096, PROT_READ | PROT_WRITE,
					MAP_SHARED | MAP_ANONYMOUS, -1, 0);
	if ((long)anon_private_touched < 0 ||
	    (long)anon_private_untouched < 0 || (long)anon_shared < 0)
		goto fail;
	*anon_private_touched = 1;
	*anon_shared = 1;

	bytes = read_maps(buffer, sizeof(buffer));
	if (bytes < 0 ||
	    !maps_contains(buffer, bytes, (unsigned long)anon_private_touched) ||
	    !maps_contains(buffer, bytes, (unsigned long)anon_private_untouched) ||
	    !maps_contains(buffer, bytes, (unsigned long)anon_shared)) {
		write_all(1, fail_root, sizeof(fail_root) - 1);
		goto fail;
	}

	if (syscall6(146, MEMHIDE_TEST_UID, 0, 0, 0, 0, 0) < 0) {
		write_all(1, fail_setuid, sizeof(fail_setuid) - 1);
		goto fail;
	}

	bytes = read_maps(buffer, sizeof(buffer));
	if (bytes < 0 || !maps_contains(buffer, bytes, (unsigned long)_start)) {
		write_all(1, fail_policy, sizeof(fail_policy) - 1);
		goto fail;
	}
#if MEMHIDE_EXPECT_HIDDEN
	if (maps_contains(buffer, bytes,
			  (unsigned long)anon_private_touched) ||
	    maps_contains(buffer, bytes,
			  (unsigned long)anon_private_untouched) ||
	    maps_contains(buffer, bytes, (unsigned long)anon_shared)) {
		write_all(1, fail_policy, sizeof(fail_policy) - 1);
		goto fail;
	}
#else
	if (!maps_contains(buffer, bytes,
			   (unsigned long)anon_private_touched) ||
	    !maps_contains(buffer, bytes,
			   (unsigned long)anon_private_untouched) ||
	    !maps_contains(buffer, bytes, (unsigned long)anon_shared)) {
		write_all(1, fail_policy, sizeof(fail_policy) - 1);
		goto fail;
	}
#endif

	write_all(1, pass, sizeof(pass) - 1);
	syscall6(93, 0, 0, 0, 0, 0, 0);

fail:
	syscall6(93, 1, 0, 0, 0, 0, 0);
}
