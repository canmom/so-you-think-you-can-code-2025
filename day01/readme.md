# Array Superpowers: Mastering Fluent LINQ in TypeScript

Most JavaScript developers love working with arrays—until they don’t.

We chain `.map()`, `.filter()`, `.reduce()` everywhere, and it works… but sometimes it feels clumsy, repetitive, and harder to read than it should be. If you’ve ever used C#’s LINQ, you know how elegant fluent data queries **can** be.

So for today’s Advent Calendar entry, I built something fun:

🎉 **`QueryableArray<T>` — a fluent, LINQ-inspired extension of the native JavaScript array.**

Not a library, not a dependency—just a tiny TypeScript class that gives your arrays superpowers.

----------

## What We Mimic From LINQ

The goal wasn’t to recreate LINQ 1:1, but to bring over the parts that make it _feel good_:

### ✔ Fluent chaining

`people.where(p => p.age > 30).orderBy(p => p.name).take(10);` 

Readable. Declarative. Zero noise.

### ✔ Query-style operators

-   `where`, `select`, `skip`, `take`
    
-   `first`, `single`, `last`
    
-   `groupBy`, `distinct`, `count`, `any`, `all`
    

These make datasets behave like proper collections, not just arrays.

### ✔ Set operations

-   `except`
    
-   `intersect`
    
-   `union`
    

Useful when merging or filtering structured data.

### ✔ Combined and advanced helpers

-   `uniqueBy(selector)`
    
-   `sortByMultiple([...])`
    
-   `paginate(page, size)`
    
-   `typescript - ts pipe(fn)` for custom pipelines
    

These cover real-world needs where `.sort()` and `.filter()` start feeling like chores.

----------

## 🔧 How It’s Built (The Short Version)

Everything is based on a simple but powerful idea:

`export  class  QueryableArray<T> extends  Array<T> { ... }` 

By extending the native `Array<T>`, you get:

-   Native behavior (length, indexing, iteration)
    
-   Full type safety
    
-   Fluent custom operators
    

Every method follows a consistent pattern:

`select<U>(selector: (item: T) => U): QueryableArray<U> { return  QueryableArray.from(this.map(selector));
}` 

Small, predictable, strongly typed.

This also means you don’t break the expectations of arrays—you enhance them.

----------

## Why Not Use an Existing Package?

There **are** packages doing similar things:

-   lodash    
-   ramda    
-   linq.js    
-   immutable.js    

They’re good. They’re powerful. But sometimes…

### A small, self-contained solution is better.

Here’s why:

### **1. Zero dependencies**

No version drift, no bundle size growth, no conflicts.

### **2. Typed exactly the way _you_ want**

Strongly typed LINQ in TypeScript often requires complex generics.  
A custom class keeps the types tight and predictable.

### **3. Fully readable code**

You can inspect, tweak, and improve everything.  
No magic, no surprises.

### **4. Perfect fit for your project**

APIs match your architecture and naming conventions.  
No compromises.

###  **5. Fun to build**

It’s a great exercise in elegant API design.

### **6.Full Code on GitHub Gist**

If you want to explore, clone, or extend the full implementation of `QueryableArray<T>`, you can find the complete TypeScript source here:

[https://gist.github.com/MagnusThor/c702f015b3ee38a6ab147dd8d9b65744](https://gist.github.com/MagnusThor/c702f015b3ee38a6ab147dd8d9b65744)

## Final Thoughts

This little `QueryableArray<T>` project is a perfect example of how TypeScript allows us to build small, expressive tools that feel big and powerful.