/// A variable-sized container that can hold any type. Indexing is 0-based, and
/// vectors are growable. This module has many native functions.
/// Verification of modules that use this one uses model functions that are implemented
/// directly in Boogie. The specification language has built-in functions operations such
/// as `singleton_vector`. There are some helper functions defined here for specifications in other
/// modules as well.
///
/// >Note: We did not verify most of the
/// Move functions here because many have loops, requiring loop invariants to prove, and
/// the return on investment didn't seem worth it for these simple functions.
module std::vector {

    /// The index into the vector is out of bounds
    const EINDEX_OUT_OF_BOUNDS: u64 = 0x20000;

    /// The index into the vector is out of bounds
    const EINVALID_RANGE: u64 = 0x20001;

    #[bytecode_instruction]
    /// Create an empty vector.
    native public fun empty<Element>(): vector<Element>;

    #[bytecode_instruction]
    /// Return the length of the vector.
    native public fun length<Element>(v: &vector<Element>): u64;

    #[bytecode_instruction]
    /// Acquire an immutable reference to the `i`th element of the vector `v`.
    /// Aborts if `i` is out of bounds.
    native public fun borrow<Element>(v: &vector<Element>, i: u64): &Element;

    #[bytecode_instruction]
    /// Add element `e` to the end of the vector `v`.
    native public fun push_back<Element>(v: &mut vector<Element>, e: Element);

    #[bytecode_instruction]
    /// Return a mutable reference to the `i`th element in the vector `v`.
    /// Aborts if `i` is out of bounds.
    native public fun borrow_mut<Element>(v: &mut vector<Element>, i: u64): &mut Element;

    #[bytecode_instruction]
    /// Pop an element from the end of vector `v`.
    /// Aborts if `v` is empty.
    native public fun pop_back<Element>(v: &mut vector<Element>): Element;

    #[bytecode_instruction]
    /// Destroy the vector `v`.
    /// Aborts if `v` is not empty.
    native public fun destroy_empty<Element>(v: vector<Element>);

    #[bytecode_instruction]
    /// Swaps the elements at the `i`th and `j`th indices in the vector `v`.
    /// Aborts if `i` or `j` is out of bounds.
    native public fun swap<Element>(v: &mut vector<Element>, i: u64, j: u64);

    /// Return an vector of size one containing element `e`.
    public fun singleton<Element>(e: Element): vector<Element> {
        let v = empty();
        push_back(&mut v, e);
        v
    }
    spec singleton {
        aborts_if false;
        ensures result == vec(e);
    }

    /// Reverses the order of the elements in the vector `v` in place.
    public fun reverse<Element>(v: &mut vector<Element>) {
        let len = length(v);
        reverse_slice(v, 0, len);
    }

    spec reverse {
        pragma intrinsic = true;
    }

    /// Reverses the order of the elements [left, right) in the vector `v` in place.
    public fun reverse_slice<Element>(v: &mut vector<Element>, left: u64, right: u64) {
        assert!(left <= right, EINVALID_RANGE);
        if (left == right) return;
        right = right - 1;
        while (left < right) {
            swap(v, left, right);
            left = left + 1;
            right = right - 1;
        }
    }
    spec reverse_slice {
        pragma intrinsic = true;
    }

    /// Pushes all of the elements of the `other` vector into the `lhs` vector.
    public fun append<Element>(lhs: &mut vector<Element>, other: vector<Element>) {
        reverse(&mut other);
        while (!is_empty(&other)) push_back(lhs, pop_back(&mut other));
        destroy_empty(other);
    }
    spec append {
        pragma intrinsic = true;
    }
    spec is_empty {
        pragma intrinsic = true;
    }

    /// Trim a vector to a smaller size, returning the evicted elements in reverse order
    public fun trim<Element>(v: &mut vector<Element>, new_len: u64): vector<Element> {
        let len = length(v);
        let result = empty();
        while (new_len < len) {
            push_back(&mut result, pop_back(v));
            len = len - 1;
        };
        result
    }


    /// Return `true` if the vector `v` has no elements and `false` otherwise.
    public fun is_empty<Element>(v: &vector<Element>): bool {
        length(v) == 0
    }

    /// Return true if `e` is in the vector `v`.
    public fun contains<Element>(v: &vector<Element>, e: &Element): bool {
        let i = 0;
        let len = length(v);
        while (i < len) {
            if (borrow(v, i) == e) return true;
            i = i + 1;
        };
        false
    }
    spec contains {
        pragma intrinsic = true;
    }

    /// Return `(true, i)` if `e` is in the vector `v` at index `i`.
    /// Otherwise, returns `(false, 0)`.
    public fun index_of<Element>(v: &vector<Element>, e: &Element): (bool, u64) {
        let i = 0;
        let len = length(v);
        while (i < len) {
            if (borrow(v, i) == e) return (true, i);
            i = i + 1;
        };
        (false, 0)
    }
    spec index_of {
        pragma intrinsic = true;
    }

    /// Remove the `i`th element of the vector `v`, shifting all subsequent elements.
    /// This is O(n) and preserves ordering of elements in the vector.
    /// Aborts if `i` is out of bounds.
    public fun remove<Element>(v: &mut vector<Element>, i: u64): Element {
        let len = length(v);
        // i out of bounds; abort
        if (i >= len) abort EINDEX_OUT_OF_BOUNDS;

        len = len - 1;
        while (i < len) swap(v, i, { i = i + 1; i });
        pop_back(v)
    }
    spec remove {
        pragma intrinsic = true;
    }

    /// Swap the `i`th element of the vector `v` with the last element and then pop the vector.
    /// This is O(1), but does not preserve ordering of elements in the vector.
    /// Aborts if `i` is out of bounds.
    public fun swap_remove<Element>(v: &mut vector<Element>, i: u64): Element {
        assert!(!is_empty(v), EINDEX_OUT_OF_BOUNDS);
        let last_idx = length(v) - 1;
        swap(v, i, last_idx);
        pop_back(v)
    }
    spec swap_remove {
        pragma intrinsic = true;
    }

    /// Apply the function to each element in the vector, consuming it.
    public inline fun for_each<Element>(v: vector<Element>, f: |Element|) {
        reverse(&mut v); // We need to reverse the vector to consume it efficiently
        for_each_reverse(v, |e| f(e));
    }

    /// Apply the function to each element in the vector, consuming it.
    public inline fun for_each_reverse<Element>(v: vector<Element>, f: |Element|) {
        while (!is_empty(&v)) {
            f(pop_back(&mut v));
        };
        destroy_empty(v)
    }

    /// Apply the function to a reference of each element in the vector.
    public inline fun for_each_ref<Element>(v: &vector<Element>, f: |&Element|) {
        let i = 0;
        let len = length(v);
        while (i < len) {
            f(borrow(v, i));
            i = i + 1
        }
    }

    /// Apply the function to a mutable reference to each element in the vector.
    public inline fun for_each_mut<Element>(v: &mut vector<Element>, f: |&mut Element|) {
        let i = 0;
        let len = length(v);
        while (i < len) {
            f(borrow_mut(v, i));
            i = i + 1
        }
    }

    /// Fold the function over the elements. For example, `fold(vector[1,2,3], 0, f)` will execute
    /// `f(f(f(0, 1), 2), 3)`
    public inline fun fold<Accumulator, Element>(
        v: vector<Element>,
        init: Accumulator,
        f: |Accumulator,Element|Accumulator
    ): Accumulator {
        let accu = init;
        for_each(v, |elem| accu = f(accu, elem));
        accu
    }

    /// Fold right like fold above but working right to left. For example, `fold(vector[1,2,3], 0, f)` will execute
    /// `f(1, f(2, f(3, 0)))`
    public inline fun foldr<Accumulator, Element>(
        v: vector<Element>,
        init: Accumulator,
        f: |Element, Accumulator|Accumulator
    ): Accumulator {
        let accu = init;
        for_each_reverse(v, |elem| accu = f(elem, accu));
        accu
    }

    /// Map the function over the references of the elements of the vector, producing a new vector without modifying the
    /// original map.
    public inline fun map_ref<Element, NewElement>(
        v: &vector<Element>,
        f: |&Element|NewElement
    ): vector<NewElement> {
        let result = vector<NewElement>[];
        for_each_ref(v, |elem| push_back(&mut result, f(elem)));
        result
    }

    /// Map the function over the elements of the vector, producing a new vector.
    public inline fun map<Element, NewElement>(
        v: vector<Element>,
        f: |Element|NewElement
    ): vector<NewElement> {
        let result = vector<NewElement>[];
        for_each(v, |elem| push_back(&mut result, f(elem)));
        result
    }

    /// Filter the vector using the boolean function, removing all elements for which `p(e)` is not true.
    public inline fun filter<Element:drop>(
        v: vector<Element>,
        p: |&Element|bool
    ): vector<Element> {
        let result = vector<Element>[];
        for_each(v, |elem| {
            if (p(&elem)) push_back(&mut result, elem);
        });
        result
    }

    /// Partition, sorts all elements for which pred is true to the front.
    /// Preserves the relative order of the elements for which pred is true,
    /// BUT NOT for the elements for which pred is false.
    public inline fun partition<Element>(
        v: &mut vector<Element>,
        pred: |&Element|bool
    ): u64 {
        let i = 0;
        let len = length(v);
        while (i < len) {
            if (!pred(borrow(v, i))) break;
            i = i + 1;
        };
        let p = i;
        i = i + 1;
        while (i < len) {
            if (pred(borrow(v, i))) {
                swap(v, p, i);
                p = p + 1;
            };
            i = i + 1;
        };
        p
    }

    fun test_stable_partition() {
        let v = vector[1, 2, 3, 4, 5];
        assert!(stable_partition(&mut v, |n| *n % 2 == 0) == 2, 0);
        assert!(&v == &vector[2, 4, 1, 3, 5], 1);
    }

    /// rotate(&mut [1, 2, 3, 4, 5], 2) -> [3, 4, 5, 1, 2] in place, returns the split point
    /// ie. 3 in the example above
    public fun rotate<Element>(
        v: &mut vector<Element>,
        rot: u64
    ): u64 {
        let len = length(v);
        rotate_slice(v, 0, rot, len)
    }

    /// Same as above but on a sub-slice of an array [left, right) with left <= rot <= right
    /// returns the
    public fun rotate_slice<Element>(
        v: &mut vector<Element>,
        left: u64,
        rot: u64,
        right: u64
    ): u64 {
        reverse_slice(v, left, rot);
        reverse_slice(v, rot, right);
        reverse_slice(v, left, right);
        left + (right - rot)
    }

    /// For in-place stable partition we need recursion so we cannot use inline functions
    /// and thus we cannot use lambdas. Luckily it so happens that we can precompute the predicate
    /// in a secondary array. Note how the algorithm belows only start shuffling items after the
    /// predicate is checked.
    public fun stable_partition_internal<Element>(
        v: &mut vector<Element>,
        pred: &vector<bool>,
        left: u64,
        right: u64
    ): u64 {
        if (left == right) {
            left
        } else if (left + 1 == right) {
            if (*borrow(pred, left)) right else left
        } else {
            let mid = left + ((right - left) >> 1);
            let p1 = stable_partition_internal(v, pred, left, mid);
            let p2 = stable_partition_internal(v, pred, mid, right);
            rotate_slice(v, p1, mid, p2)
        }
    }

    /// Partition the array based on a predicate p, this routine is stable and thus
    /// preserves the relative order of the elements in the two partitions.
    public inline fun stable_partition<Element>(
        v: &mut vector<Element>,
        p: |&Element|bool
    ): u64 {
        let pred = map_ref(v, |e| p(e));
        let len = length(v);
        stable_partition_internal(v, &pred, 0, len)
    }

    /// Return true if any element in the vector satisfies the predicate.
    public inline fun any<Element>(
        v: &vector<Element>,
        p: |&Element|bool
    ): bool {
        let result = false;
        let i = 0;
        while (i < length(v)) {
            result = p(borrow(v, i));
            if (result) {
                break
            };
            i = i + 1
        };
        result
    }

    /// Return true if all elements in the vector satisfy the predicate.
    public inline fun all<Element>(
        v: &vector<Element>,
        p: |&Element|bool
    ): bool {
        let result = true;
        let i = 0;
        while (i < length(v)) {
            result = p(borrow(v, i));
            if (!result) {
                break
            };
            i = i + 1
        };
        result
    }

    /// Destroy a vector, just a wrapper around for_each_reverse with a descriptive name
    /// when used in the context of destroying a vector.
    public inline fun destroy<Element>(
        v: vector<Element>,
        d: |Element|
    ) {
        for_each_reverse(v, |e| d(e))
    }

    // =================================================================
    // Module Specification

    spec module {} // Switch to module documentation context

    /// # Helper Functions

    spec module {
        /// Check if `v1` is equal to the result of adding `e` at the end of `v2`
        fun eq_push_back<Element>(v1: vector<Element>, v2: vector<Element>, e: Element): bool {
            len(v1) == len(v2) + 1 &&
            v1[len(v1)-1] == e &&
            v1[0..len(v1)-1] == v2[0..len(v2)]
        }

        /// Check if `v` is equal to the result of concatenating `v1` and `v2`
        fun eq_append<Element>(v: vector<Element>, v1: vector<Element>, v2: vector<Element>): bool {
            len(v) == len(v1) + len(v2) &&
            v[0..len(v1)] == v1 &&
            v[len(v1)..len(v)] == v2
        }

        /// Check `v1` is equal to the result of removing the first element of `v2`
        fun eq_pop_front<Element>(v1: vector<Element>, v2: vector<Element>): bool {
            len(v1) + 1 == len(v2) &&
            v1 == v2[1..len(v2)]
        }

        /// Check that `v1` is equal to the result of removing the element at index `i` from `v2`.
        fun eq_remove_elem_at_index<Element>(i: u64, v1: vector<Element>, v2: vector<Element>): bool {
            len(v1) + 1 == len(v2) &&
            v1[0..i] == v2[0..i] &&
            v1[i..len(v1)] == v2[i + 1..len(v2)]
        }

        /// Check if `v` contains `e`.
        fun spec_contains<Element>(v: vector<Element>, e: Element): bool {
            exists x in v: x == e
        }
    }

}
