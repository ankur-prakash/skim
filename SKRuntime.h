/*
 *  SKRuntime.h
 *  Skim
 *
 *  Created by Christiaan Hofman on 7/23/08.
/*
 This software is Copyright (c) 2008
 Christiaan Hofman. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Christiaan Hofman nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <objc/objc-runtime.h>

// wrappers around 10.5 only functions, use 10.4 API when the function is not defined

#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5

#pragma mark 10.4 + 10.5

extern void _objc_flush_caches(Class);

static inline Class SK_object_getClass(id object) {
    return object_getClass != NULL ? object_getClass(object) : object->isa;
}

static inline IMP SK_method_getImplementation(Method aMethod) {
    return method_getImplementation != NULL ? method_getImplementation(aMethod) : aMethod->method_imp;
} 

static inline IMP SK_method_setImplementation(Method aMethod, IMP anImp) {
    if (method_setImplementation != NULL) {
        return method_setImplementation(aMethod, anImp);
    } else {
        IMP oldImp = aMethod->method_imp;
        aMethod->method_imp = anImp;
        return oldImp;
    }
} 

static inline void SK_method_exchangeImplementations(Method aMethod1, Method aMethod2) {
    if (method_exchangeImplementations != NULL) {
        method_exchangeImplementations(aMethod1, aMethod2);
    } else {
        IMP imp = aMethod1->method_imp;
        aMethod1->method_imp = aMethod2->method_imp;
        aMethod2->method_imp = imp;
    }
}

static inline const char *SK_method_getTypeEncoding(Method aMethod) {
    return method_getTypeEncoding != NULL ? method_getTypeEncoding(aMethod) : aMethod->method_types;
}

static inline Class SK_class_getSuperclass(Class aClass) {
    return class_getSuperclass != NULL ? class_getSuperclass(aClass) : aClass->super_class;
}

static inline void SK_class_addMethod(Class aClass, SEL selector, IMP methodImp, const char *methodTypes) {
    if (class_addMethod != NULL) {
        class_addMethod(aClass, selector, methodImp, methodTypes);
    } else {
        struct objc_method_list *newMethodList = (struct objc_method_list *)NSZoneMalloc(NSDefaultMallocZone(), sizeof(struct objc_method_list));
        
        newMethodList->method_count = 1;
        newMethodList->method_list[0].method_name = selector;
        newMethodList->method_list[0].method_imp = methodImp;
        newMethodList->method_list[0].method_types = (char *)methodTypes;
        
        class_addMethods(aClass, newMethodList);
        
        // Flush the method cache
        _objc_flush_caches(aClass);
    }
}

#else

#pragma mark 10.5

static inline Class SK_object_getClass(id object) {
    return object_getClass(object);
}

static inline IMP SK_method_getImplementation(Method aMethod) {
    return method_getImplementation(aMethod);
} 

static inline IMP SK_method_setImplementation(Method aMethod, IMP anImp) {
    return method_setImplementation(aMethod, anImp);
} 

static inline void SK_method_exchangeImplementations(Method aMethod1, Method aMethod2) {
    method_exchangeImplementations(aMethod1, aMethod2);
}

static inline const char *SK_method_getTypeEncoding(Method aMethod) {
    return method_getTypeEncoding(aMethod);
}

static inline Class SK_class_getSuperclass(Class aClass) {
    return class_getSuperclass(aClass);
}

static inline void SK_class_addMethod(Class aClass, SEL selector, IMP methodImp, const char *methodTypes) {
    class_addMethod(aClass, selector, methodImp, methodTypes);
}

#endif

static inline Method SK_class_getMethod(Class aClass, SEL aSelector, BOOL isInstance) {
    return isInstance ? class_getInstanceMethod(aClass, aSelector) : class_getClassMethod(aClass, aSelector);
}