/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _MEMHIDE_TEST_INTERNAL_H
#define _MEMHIDE_TEST_INTERNAL_H

#include <linux/types.h>

struct vm_area_struct;

bool memhide_test_enabled(void);
void memhide_test_audit_maps_vma(struct vm_area_struct *vma);
bool memhide_test_should_hide_maps_vma(struct vm_area_struct *vma);

#endif /* _MEMHIDE_TEST_INTERNAL_H */
