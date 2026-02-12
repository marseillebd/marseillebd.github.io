# An Informal Type-Theoretic Analysis of Interfaces for Resource Acquisition and Release

Despite the pretentious title, I'm really talking about manual memory management vs garbage collection.
The lessons learned in memory management do apply to other forms of resources, though, such as locks or database connections or VBAs and so on.

The answer is "it depends".
Absolute shocker that it's the same answer as everywhere else in computer science.
Sure, we can spend a lot of time mapping out the conditions that indicate one or the other choice, but that's not what I'm interested in here.
The fact is, whatever decision procedure we find is likely to produce wrong answers, and even more relevant: **developers consistently fail to predict requirements**.
Realistically, the requirements change under our feet and we have to adapt.

So what's the problem?
We own the code, so we can swap from manual to managed memory and vice-versa, right?
In any serious body of code, that turns out to be a lot of effort.
You are locked-in once you make the decision.
The one thing I will map out is that at the start of a project it seems like managed memory is the way to go because it gets prototypes out the door quickly,
    but then managed memory becomes a performance bottleneck as load increases.
Worse, even if you do change all your own code, your dependencies have already made their choices, so you may have to rework your entire software stack.

## Naive Allocator-Polymorphism

So, what we need are interfaces that are allocator-polymorphic, right?
Just inject the allocator as a dependency.
To be concrete, let's consider the interface for a element-polymorphic dynamic array in pseudo-C.
I'm only going to address a fraction of the external interface; the rest is immaterial and you can fill it in.

```
declare type dynarr<elem_t>;

size_t length(DynArr<elem_t>);
elem_t index(DynArr<elem_t>, size_t i);
void append(DynArr<elem_t>, elem_t);
```

So far so good, but we have no way to construct a dynamic array.
If we weren't being allocator-polymorphic, we'd just use `malloc` under the hood, but that locks-in our memory management strategy.
Instead, we need to inject the allocator as a dependency.
Since we'll be doing this all over the code base, we may as well write the allocator intrerface once.

```
struct Allocator {
    alloc: fn<T>(size_t count) -> ptr<T>;
    free: fn<T>(ptr<T>) -> void;
};
```

Although this interface looks like it is for manual management, it can be re-used for automatic management by simply initializing `free` to a no-op.
Now, we just need to supply an allocator to each dynamic array we create.
Here, we do this with an explicit argument for familiarity, but
    there are well-known techniques to _infer_ this argument, so the ergonomics remain comfortable.

```
DynArr<elem_t> new(Allocator);
DynArr<elem_t> delete(Allocator);
```

Now, I just have a few questions:
- Can the result of indexing be copied? Can it be aliased?
- If I append, do I need to free later, or does the array take ownership?
- If an element has an alias before it is appended, is that alias still valid after the array is free'd?

If we attempt to use this interface in both managed and unmanaged contexts, we need to be conservative with our answers.
That means we need to treat this array as manually-managed, thus erasing the clarity[^clarity] advantage of a managed approach.
Perhaps it is no wonder that many programers who have had to write manually-managed code discount garbage collection seemingly out-of-hand.
Attempts to create interfaces that can swap out allocators from manual to automatic and vice-versa fail.

[^clarity]: "Clarity" is a vague word.
What I mean is that garbage collection separates out the often boring details of memory management
    from the interesting logical/buissiness problem that we are writing, and especially, later reading.

By the way, the interface mismatch is not limited to garbage-collection.
Polymorphisim between manual management and scratch allocators have the same issues.

## Type-Theoretic Analysis

The question for anyone waking along this line of thought is
    **why did the solution fail even though the interface looked good?**
From a type-theoretic perspective, the answer is simple:
    **our type system does not capture what it means to do memory management correctly.**
That's not a fundamental limit of type systems, however.
So-called linear types are well-known to model and check for correct resource management.
Memory is just another resource.

In our hypothetical type system, each variable will not only be equipped with a type, but also a _quantity_.
For simplicity, quantity will come in two forms "unrestructed" (written `*`) and "linear" (written `1`).
Any time we give an ordinary type, we'll also give the quantity just before the type.
Unrestricted quantity is what you are used to: you can "use" the variable as many times as you like, including not at all.
Linear quantity variables require you to "use" that variable exactly once.
(Readers already familiar with linear types will note that my presentation differs from the usual implementation, but I find the usual implementation to require knowledge of continuation passing, and I'd rather not have another dependency on this already niche article.)

But what the heck does "using" mean?
Of course, not only variables, but also function parameters and return values will be equipped with quantity, and this is where "quantity" gains a meaning.
If a function returns a linear value, the caller is responsible for "cleaning up" that return value, perhaps `free` or `fclose` or whatever.
If a function takes a linear parameter, then it promises to clean up that value.
Note, the cleanup may not be direct: a function receiving a linear parameter might pass it back as a return value, which is called a "borrow".
This is the heart of the "linear types model resources" slogan.
All we have to do is write interfaces that specify the allocation and deallocation, and the type system makes sure the rest of the code is doing the bookkeeping correctly.

### Manual Memory Management

So, let's consider the interface for manual memory management again.
We need a function that allocates memory, and for which the caller is responsible for making sure cleanup happens.
We also need a function that deallocates that same memory, which does the cleanup.
This means we'll be creating/destroying a _linear_ pointer.
We'll also need to read/write with this pointer, which we can do with borrows.

```
1 ownptr<T> manAlloc();
manFree(1 ownptr<T>);

(T, 1 ownptr<T>) read<T>(1 ownptr<T>);
1 ownptr<T> write(1 ownptr<T>, T);

int main() {
    1 ownptr<int> ecPtr = manAlloc();
    ecPtr = write(ecPtr, 0);

    // ... anything goes, as long as we don't call `free(ecPtr)` in here

    ec, ecPtr = read(ecPtr);
    manFree(ecPtr);
    // ^ not including this line will cause a compiler error, because you forgot to free the pointer you allocated

    // read(ecPtr); // this line would fail to compile because it's a use-after-free
    // manFree(ecPtr); // this line would fail to compile because it's a double-free

    return ec;
}
```

In practice, constantly re-assigning the same resource to the same variable a bunch is annoying.
So for convenience, there is usually a special syntax for borrowing, which I'll show as well.

```
T read<T>(& ownptr<T>);
void write(& ownptr<T>, T);

int main() {
    1 ownptr<int> ecPtr = malloc();
    write(ecPtr, 0);

    // ... anything goes, as long as we don't call `free(ecPtr)` in here

    ec = read(ecPtr);
    free(ecPtr);

    return ec;
}
```

Under the hood, `manAlloc`, `manFree`, `read` and `write` will have to cast/convert/unwrap the abstract `ownptr` resource into an ordinary `uintptr_t` value.
However, if we keep the internal representation of `ownptr` abstract --- basic encapsulation --- then we gain a significant advantage.
To verify our program does not crash as a result of using `manAlloc`'d memory, all we have to do is the small task of verifying the core implementation,
    and then the type check does the rest automatically, no matter how large or complex our program gets.

By the way, I've heard expert C programmers dismiss this property of Rust code because they can and do write memory-safe code in C all the time.
Yes, of course you can write memory-safe code in C, but if you want to _verify_ your code to be memory-safe, you have to do a lot of work.
Even tools like address sanitization or valgrind which speed up the process still take _ages_ to run compared to the Rust compiler.

### Automatic Memory Management

With garbage collection, you allocate, but you need not worry about freeing, or any of the related bookkeeping.
You are trusting the collector to do an adequate job itself, and in many if not most cases it can.
The advantage is not just that the interface need not have `free`, but it also need not use linear types.

```
gcptr<T> gcAlloc();

T read<T>(gcptr<T>);
void write(gcptr<T>, T);

int main() {
    gcptr<int> ecPtr = gcAlloc();
    ecPtr = write(ecPtr, 0);

    // ... anything goes, actually anything this time

    ec = read(ecPtr);

    // never had to remember to call anything, much less exactly once, nor at any particular time
    // that reduces cognitive overhead, leaving room for solving other problems
    return ec;
}
```

This interface is very boring --- which is the point --- so there's not much to talk about here.
Keen readers might recognize one issue with this interface, which I'll get into below.
For now, I'll simply put the interfaces side-by-side so that we can see exactly the differences and similarities.
Of course, we see the gap for `gcFree`, but as already noted, a simple no-op can stand-in.
The only other difference is that the pointers manipulated in each interface differ in their linearity.
I think you can see how this would have dramatic implications for variable use and control flow,
    even though C-like type systems cannot capture it.

```
1 ownptr<T> manAlloc();               gcptr<T> gcAlloc();
            manFree(1 ownptr<T>);
T           read<T>(& ownptr<T>);     T        read<T>(gcptr<T>);
void        write(& ownptr<T>, T);    void     write(gcptr<T>, T);
```

This answers why the naive interface dose not work in practice, but that wasn't our original question.
Remember, we want to build a system with one form of memory management while being able to switch to the other.

## Migrating Between Manual and Automatic Management

I'm not sure there is a common interface (that's at all easy to explain or use) where you can simply inject either sort of allocator.
So long allocator-polymorphic data structures; we'll have to provide separate implementations for all the data structures we want to swap between.
Then, we'll need to be able to move memory between the manual and automatic worlds.

Moving data from manual management to automatic is simple.
The garbage collector simply takes ownership of the raw pointer, and is instructed to cleanup with a finalizer.
This is already well-implemented in any language that has garbage collection.

Working with managed memory from a manually-managed language is much less well-known.
Something that makes garbage collection so pleasant to work with is that they are generally supported by a runtime
    that can trace the registers and stack for any references to managed memory.
In a language such as C, there is no such support, so while we might be able to automatically manage memory,
    we still need to manually manage the _root set_.
This root set is the missing part of the `gcAlloc` interface I mentioned previously.

```
(gcptr<T>, 1 gcRoot) gcAlloc();
void gcUnroot(1 gcRoot);

T read<T>(gcptr<T>);
void write(gcptr<T>, T);

int main() {
    gcptr<int> ecPtr, gcRoot root = gcAlloc();
    ecPtr = write(ecPtr, 0);

    // ... anything goes, actually anything this time

    ec = read(ecPtr);
    gcUnroot(root);
    // ^ this is the optimal place to unroot, since ecPtr isn't used again after this point

    return ec;
}
```

The above interface is the least sophisticated way of managing gc roots.
Thankfully, managing a rootset is much simpler than managing pointers, as roots tend to go out of scope as soon as (or before) a function returns.
In fact, for most purposes it is probably sufficient to use a stack of scratch allocators for roots.

If I'm honset, we're well into my musings at this point.
There are definite constraints on the lifetime of the root vs the `gcptr` that we obtained.
Also, a moving garbage collector might invalidate a `gcptr` if it's implemented as a simple pointer.
There's certainly an argument to be made that unmanaged code should only be able to access managed memory through roots.
Less strict APIs may be possible, but characterizing (designing, reading, and using) is certainly a more difficult problem.
Perhaps a rank-2 type may be able to let us read type-level-tagged pointers from a single root without allowing those pointers to escape where the root is known to be valid, while not requiring constant modification to the rootset.

## Conclusion

I certainly haven't solved the problem of safely embedding a garbage collector into an unmanaged language.
I want to, though, and hopefully in an ergonomic and efficient way.
Embedded scripting languages are similar, but they have constrained patterns of data-sharing: the script calls a primitive or the runtime invokes a scripted callback.
What I am looking for is a _library_ I can use in an unmanaged context which allows me to use managed resources, no matter the complexity of the data sharing between the managed and unmanaged heaps.
I believe that would offer a smoother transition from managed to unmanaged memory:
    simply start in an unmanaged language using that library, and then swap out components' allocation strateies as needed,
    at the cost of managing a rootset.
