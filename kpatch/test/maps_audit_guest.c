/* SPDX-License-Identifier: GPL-2.0 */
/* Freestanding ARM64 guest test: create VMAs and read /proc/self/maps. */
#define AT_FDCWD (-100)
#define PROT_READ 0x1
#define PROT_WRITE 0x2
#define MAP_SHARED 0x01
#define MAP_PRIVATE 0x02
#define MAP_ANONYMOUS 0x20

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

void _start(void)
{
	static const char maps_path[] = "/proc/self/maps";
	static const char pass[] = "MAPS_AUDIT_GUEST=PASS\n";
	static const char fail_message[] = "MAPS_AUDIT_GUEST=FAIL\n";
	char buffer[1024];
	volatile char *anon_private;
	volatile char *anon_shared;
	long fd, bytes;

	anon_private = (void *)syscall6(222, 0, 4096, PROT_READ | PROT_WRITE,
					 MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	anon_shared = (void *)syscall6(222, 0, 4096, PROT_READ | PROT_WRITE,
					MAP_SHARED | MAP_ANONYMOUS, -1, 0);
	if ((long)anon_private < 0 || (long)anon_shared < 0)
		goto fail;
	*anon_private = 1;
	*anon_shared = 1;

	fd = syscall6(56, AT_FDCWD, (long)maps_path, 0, 0, 0, 0);
	if (fd < 0)
		goto fail;
	do {
		bytes = syscall6(63, fd, (long)buffer, sizeof(buffer), 0, 0, 0);
	} while (bytes > 0);
	syscall6(57, fd, 0, 0, 0, 0, 0);
	if (bytes < 0)
		goto fail;
	write_all(1, pass, sizeof(pass) - 1);
	syscall6(93, 0, 0, 0, 0, 0, 0);

fail:
	write_all(1, fail_message, sizeof(fail_message) - 1);
	syscall6(93, 1, 0, 0, 0, 0, 0);
}
