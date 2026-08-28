// SPDX-License-Identifier: GPL-2.0
/* Minimal inert in-tree research-module scaffold. */
#include <linux/export.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/tracepoint.h>

#include "memhide_test.h"

bool memhide_test_enabled(void)
{
	return true;
}
EXPORT_SYMBOL_GPL(memhide_test_enabled);

#ifdef CONFIG_MEMHIDE_TEST_AUDIT
enum memhide_test_vma_kind {
	MEMHIDE_TEST_VMA_ANON_PRIVATE,
	MEMHIDE_TEST_VMA_ANON_SHARED,
	MEMHIDE_TEST_VMA_FILE,
	MEMHIDE_TEST_VMA_SPECIAL,
};

static enum memhide_test_vma_kind
memhide_test_vma_kind(const struct vm_area_struct *vma)
{
	if (vma->vm_file)
		return MEMHIDE_TEST_VMA_FILE;
	if (vma->vm_flags & VM_SHARED)
		return MEMHIDE_TEST_VMA_ANON_SHARED;
	if (vma->anon_vma)
		return MEMHIDE_TEST_VMA_ANON_PRIVATE;
	return MEMHIDE_TEST_VMA_SPECIAL;
}

void memhide_test_audit_maps_vma(const struct vm_area_struct *vma)
{
	/* This experiment is deliberately limited to /proc/self/maps. */
	if (current->mm != vma->vm_mm)
		return;

	trace_printk("memhide_test_maps tgid=%d start=%#lx end=%#lx flags=%#lx kind=%u file=%u anon_vma=%u\\n",
		     task_tgid_nr(current), vma->vm_start, vma->vm_end,
		     vma->vm_flags, memhide_test_vma_kind(vma), !!vma->vm_file,
		     !!vma->anon_vma);
}
EXPORT_SYMBOL_GPL(memhide_test_audit_maps_vma);
#endif
