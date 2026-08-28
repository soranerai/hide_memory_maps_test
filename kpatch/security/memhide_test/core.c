// SPDX-License-Identifier: GPL-2.0
/* Minimal in-tree memory-map filtering experiment. */
#include <linux/export.h>
#include <linux/cred.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/shmem_fs.h>
#include <linux/tracepoint.h>

#include "memhide_test.h"

bool memhide_test_enabled(void)
{
	return true;
}
EXPORT_SYMBOL_GPL(memhide_test_enabled);

#ifdef CONFIG_MEMHIDE_TEST_AUDIT
#define MEMHIDE_TEST_HIDDEN_UID 12345U

enum memhide_test_vma_kind {
	MEMHIDE_TEST_VMA_ANON_PRIVATE,
	MEMHIDE_TEST_VMA_ANON_SHARED,
	MEMHIDE_TEST_VMA_FILE,
	MEMHIDE_TEST_VMA_SPECIAL,
};

static enum memhide_test_vma_kind
memhide_test_vma_kind(const struct vm_area_struct *vma)
{
	/* MAP_SHARED | MAP_ANONYMOUS is implemented with an internal shmem file,
	 * so vm_file is non-NULL.  Recognize that case before generic file-backed
	 * mappings.
	 */
	if ((vma->vm_flags & VM_SHARED) && vma->vm_file &&
	    shmem_file(vma->vm_file))
		return MEMHIDE_TEST_VMA_ANON_SHARED;
	if (vma->vm_file)
		return MEMHIDE_TEST_VMA_FILE;
	if (vma->anon_vma)
		return MEMHIDE_TEST_VMA_ANON_PRIVATE;
	return MEMHIDE_TEST_VMA_SPECIAL;
}

void memhide_test_audit_maps_vma(const struct vm_area_struct *vma)
{
	/* This experiment is deliberately limited to /proc/self/maps. */
	if (current->mm != vma->vm_mm)
		return;

	trace_printk("memhide_test_maps tgid=%d uid=%u start=%#lx end=%#lx flags=%#lx kind=%u file=%u anon_vma=%u hide=%u\\n",
		     task_tgid_nr(current), __kuid_val(current_uid()),
		     vma->vm_start, vma->vm_end,
		     vma->vm_flags, memhide_test_vma_kind(vma), !!vma->vm_file,
		     !!vma->anon_vma, memhide_test_should_hide_maps_vma(vma));
}
EXPORT_SYMBOL_GPL(memhide_test_audit_maps_vma);

bool memhide_test_should_hide_maps_vma(const struct vm_area_struct *vma)
{
	return __kuid_val(current_uid()) == MEMHIDE_TEST_HIDDEN_UID &&
	       memhide_test_vma_kind(vma) == MEMHIDE_TEST_VMA_ANON_SHARED;
}
EXPORT_SYMBOL_GPL(memhide_test_should_hide_maps_vma);
#endif
