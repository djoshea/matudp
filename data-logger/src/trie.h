#ifndef _TRIE_H_INCLUDED_
#define _TRIE_H_INCLUDED_

// A simple implementation of a Trie with 256 branches at each level
// O(m) lookup, insert times where m is length of string

#include <stdbool.h>

#define TRIEFANOUT 256
typedef struct Trie
{
   void* value; 
   struct Trie* edges[TRIEFANOUT];
   struct Trie* parent;
   unsigned indexInParent;
} Trie;

Trie* trie_create();
void trie_add(Trie*, const char*, void*);
Trie* trie_find(Trie*, const char*);
unsigned trie_count(Trie*);
void trie_callOnEach(Trie*, void (*)(void *));
unsigned trie_accumulate(Trie *, unsigned (*)(void*));
void* trie_lookup(Trie*, const char*); 
void trie_flush(Trie *, void (*)(void*));

// trie iteration, start with root node and then call trie_get_next
Trie* trie_get_next(Trie*);

// used internally by trie_get_next
Trie* trie_get_next_child(Trie*, unsigned);

Trie* trie_get_first(Trie*);

#endif

