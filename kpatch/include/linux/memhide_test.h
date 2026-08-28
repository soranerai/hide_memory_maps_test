/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _LINUX_MEMHIDE_TEST_H
#define _LINUX_MEMHIDE_TEST_H

#include <linux/types.h>

struct vm_area_struct;

/* Public boundary for future, explicitly reviewed test hooks. */
#ifdef CONFIG_MEMHIDE_TEST
bool memhide_test_enabled(void);
#ifdef CONFIG_MEMHIDE_TEST_AUDIT
void memhide_test_audit_maps_vma(struct vm_area_struct *vma);
bool memhide_test_should_hide_maps_vma(struct vm_area_struct *vma);
#else
static inline void memhide_test_audit_maps_vma(struct vm_area_struct *vma)
{
}
static inline bool
memhide_test_should_hide_maps_vma(struct vm_area_struct *vma)
{
	return false;
}
#endif
#else
static inline bool memhide_test_enabled(void)
{
	return false;
}
static inline void memhide_test_audit_maps_vma(struct vm_area_struct *vma)
{
}
static inline bool
memhide_test_should_hide_maps_vma(struct vm_area_struct *vma)
{
	return false;
}
#endif

#endif /* _LINUX_MEMHIDE_TEST_H */
