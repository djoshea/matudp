#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "utils.h"
#include "trie.h"

Trie* trie_create() {
    Trie *node = (Trie*)CALLOC(1, sizeof(Trie)); 
    return node;
}

void trie_add(Trie *node, const char *str, void* value) {
    if(((uint8_t*)str)[0] == '\0') {
        // this is last letter, store value here
        node->value = value;
    } else {
        if (node->edges[((uint8_t*)str)[0]] == NULL) {
            // allocate a leaf at index str[0]
            node->edges[((uint8_t*)str)[0]] = trie_create();

            // point it back to me
            node->edges[((uint8_t*)str)[0]]->parent = node;
            node->edges[((uint8_t*)str)[0]]->indexInParent = ((uint8_t*)str)[0];
        } 
        // add the remaining string there
        trie_add(node->edges[((uint8_t*)str)[0]], str+1, value);
    }
}      

Trie* trie_find(Trie *node, const char *str) {
    if(((uint8_t*)str)[0] == '\0') {
        // this is last letter, retrieve value here
        return node;
    } else {
        if (node->edges[((uint8_t*)str)[0]] == NULL) {
            return NULL;
        } else {
            // search the leaf at index str[0]
            return trie_find(node->edges[((uint8_t*)str)[0]], str+1);
        }
    }
}

void* trie_lookup(Trie *node, const char *str) {
    Trie* found = trie_find(node, str); 
    if(found == NULL) {
        return NULL;
    } else {
        return found->value;
    }
} 

// count the number of non-NULL valued trie nodes in the trie
unsigned trie_count(Trie* node) {
    return trie_accumulate(node, NULL);
}

void trie_callOnEach(Trie* node, void (*fn)(void *)) {
    // call on all my occupied edges
    for(unsigned i = 0; i < TRIEFANOUT; i++) {
        if(node->edges[i] != NULL) {
            trie_callOnEach(node->edges[i], fn);
        }
    }
    
    // call on me (call on me!)
    if(node->value != NULL)
        fn(node->value);
}

// sum the results of calling accumFn on all non-NULL values in the trie
// if accumFn == NULL, counts the number of non-NULL values
unsigned trie_accumulate(Trie *node, unsigned (*accumFn)(void*))
{
    unsigned accum = 0;

    // accumulate over all my occupied edges
    for(unsigned i = 0; i < TRIEFANOUT; i++) {
        if(node->edges[i] != NULL) {
            accum += trie_accumulate(node->edges[i], accumFn);
        }
    }
    
    // and accumulate my value
    if(node->value != NULL) {
        if(accumFn == NULL)
            accum++;
        else
            accum += accumFn(node->value);
    }

    return accum;
}

// returns the next trie node using DFS
// starting with the root, this will iterate through all nodes in the tree
Trie* trie_get_next(Trie *node) { 
    // first, search over each edge
    for(unsigned i = 0; i < TRIEFANOUT; i++) {
        if(node->edges[i] != NULL) {
            if(node->edges[i]->value != NULL) {
                // this edge has a value, return it
                return node->edges[i];
            } else {
                // this edge has no value but has children
                return trie_get_next(node->edges[i]);
            }
        }
    }

    // I have no children, try to ask my parent for my next sibling
    if(node->parent == NULL)
        return NULL;
    return trie_get_next_child(node->parent, node->indexInParent);
}

// called from trie_get_next, when a child is searching for its next adjacent 
// sibling, the parent node will return the next child after offset
Trie * trie_get_next_child(Trie* node, unsigned offset) {
    for(unsigned i = offset+1; i < TRIEFANOUT; i++) {
        if(node->edges[i] != NULL) {
            if(node->edges[i]->value != NULL) {
                // this edge has a value, return it
                return node->edges[i];
            } else {
                // this edge has no value but has children 
                return trie_get_next(node->edges[i]);
            }
        }
    }

    // we've run out of children, try my parent
    if(node->parent == NULL)
        return NULL;
    return trie_get_next_child(node->parent, node->indexInParent);
}

// get the first non-empty value in trie
Trie* trie_get_first(Trie* node) {
    if(node->value != NULL)
        return node;
    else
        return trie_get_next(node);
}

void trie_flush(Trie *node, void (*freeValueFn)(void*))
{
    // free all my occupied edges
    for(unsigned i = 0; i < TRIEFANOUT; i++) {
        if(node->edges[i] != NULL) {
            trie_flush(node->edges[i], freeValueFn);
        }
    }
    
    // execute the callback on the value
    if(freeValueFn != NULL && node->value != NULL)
        freeValueFn(node->value);

    // free me
    FREE(node);
}

