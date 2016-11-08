using Base.Test
import Base: tuple_type_cons, tuple_type_head, tuple_type_tail, in, ==, isless, convert,
             length, eltype, start, next, done, show

eltypes(::Type{Tuple{}}) = Tuple{}
eltypes{T<:Tuple}(::Type{T}) =
    tuple_type_cons(eltype(tuple_type_head(T)), eltypes(tuple_type_tail(T)))

# sizehint, making sure to return first argument
_sizehint!{T}(a::Array{T,1}, n::Integer) = (sizehint!(a, n); a)
_sizehint!(a::AbstractArray, sz::Integer) = a

# argument selectors
left(x, y) = x
right(x, y) = y

# tuple and NamedTuple utilities

@inline ith_all(i, ::Tuple{}) = ()
@inline ith_all(i, as) = (as[1][i], ith_all(i, tail(as))...)

@generated function ith_all(i, n::NamedTuple)
    Expr(:block,
         :(@Base._inline_meta),
         Expr(:tuple, [ Expr(:ref, Expr(:., :n, Expr(:quote, fieldname(n,f))), :i) for f = 1:nfields(n) ]...))
end

@generated function map(f, n::NamedTuple)
    Expr(:call, Expr(:macrocall, Symbol("@NT"), fieldnames(n)...),
         [ Expr(:call, :f, Expr(:., :n, Expr(:quote, fieldname(n,f)))) for f = 1:nfields(n) ]...)
end

@inline foreach(f, a::Tuple) = _foreach(f, a[1], tail(a))
@inline _foreach(f, x, ra) = (f(x); _foreach(f, ra[1], tail(ra)))
@inline _foreach(f, x, ra::Tuple{}) = f(x)

@generated function foreach(f, n::NamedTuple)
    Expr(:block, [ Expr(:call, :f, Expr(:., :n, Expr(:quote, fieldname(n,f)))) for f = 1:nfields(n) ]...)
end

@inline foreach(f, a::Tuple, b::Tuple) = _foreach(f, a[1], b[1], tail(a), tail(b))
@inline _foreach(f, x, y, ra, rb) = (f(x, y); _foreach(f, ra[1], rb[1], tail(ra), tail(rb)))
@inline _foreach(f, x, y, ra::Tuple{}, rb) = f(x, y)

@generated function foreach(f, n::Union{Tuple,NamedTuple}, m::Union{Tuple,NamedTuple})
    Expr(:block,
         :(@Base._inline_meta),
         [ Expr(:call, :f,
                Expr(:call, :getfield, :n, f),
                Expr(:call, :getfield, :m, f)) for f = 1:nfields(n) ]...)
end

fieldindex(x, i::Integer) = i
fieldindex(x::NamedTuple, s::Symbol) = findfirst(x->x===s, fieldnames(x))

astuple(t::Tuple) = t

@generated function astuple(n::NamedTuple)
    Expr(:tuple, [ Expr(:., :n, Expr(:quote, fieldname(n,f))) for f = 1:nfields(n) ]...)
end

# family of projection functions

immutable Proj{field}; end

(::Proj{field}){field}(x) = getfield(x, field)

pick(fld) = Proj{fld}()

# lexicographic order product iterator

import Base: length, eltype, start, next, done

abstract AbstractProdIterator

immutable Prod2{I1, I2} <: AbstractProdIterator
    a::I1
    b::I2
end

product(a) = a
product(a, b) = Prod2(a, b)
eltype{I1,I2}(::Type{Prod2{I1,I2}}) = Tuple{eltype(I1), eltype(I2)}
length(p::AbstractProdIterator) = length(p.a)*length(p.b)

function start(p::AbstractProdIterator)
    s1, s2 = start(p.a), start(p.b)
    s1, s2, (done(p.a,s1) || done(p.b,s2))
end

function prod_next(p, st)
    s1, s2 = st[1], st[2]
    v2, s2 = next(p.b, s2)
    doneflag = false
    if done(p.b, s2)
        v1, s1 = next(p.a, s1)
        if !done(p.a, s1)
            s2 = start(p.b)
        else
            doneflag = true
        end
    else
        v1, _ = next(p.a, s1)
    end
    return (v1,v2), (s1,s2,doneflag)
end

next(p::Prod2, st) = prod_next(p, st)
done(p::AbstractProdIterator, st) = st[3]

immutable Prod{I1, I2<:AbstractProdIterator} <: AbstractProdIterator
    a::I1
    b::I2
end

product(a, b, c...) = Prod(a, product(b, c...))
eltype{I1,I2}(::Type{Prod{I1,I2}}) = tuple_type_cons(eltype(I1), eltype(I2))

function next{I1,I2}(p::Prod{I1,I2}, st)
    x = prod_next(p, st)
    ((x[1][1],x[1][2]...), x[2])
end

# sortperm with counting sort

sortperm_fast(x; alg=MergeSort, kwargs...) = sortperm(x, alg=alg, kwargs...)

function sortperm_fast{T<:Integer}(v::Vector{T})
    n = length(v)
    if n > 1
        min, max = extrema(v)
        rangelen = max - min + 1
        if rangelen < div(n,2)
            return sortperm_int_range(v, rangelen, min)
        end
    end
    return sortperm(v, alg=MergeSort)
end

function sortperm_int_range{T<:Integer}(x::Vector{T}, rangelen, minval)
    offs = 1 - minval
    n = length(x)

    where = fill(0, rangelen+1)
    where[1] = 1
    @inbounds for i = 1:n
        where[x[i] + offs + 1] += 1
    end
    cumsum!(where, where)

    P = Vector{Int}(n)
    @inbounds for i = 1:n
        label = x[i] + offs
        wl = where[label]
        P[wl] = i
        where[label] = wl+1
    end

    return P
end

# sort the values in v[i0:i1] in place, by array `by`
function sort_sub_by!(v, i0, i1, by, order, temp)
    empty!(temp)
    sort!(v, i0, i1, MergeSort, order, temp)
end

function sort_sub_by!{T<:Integer}(v, i0, i1, by::Vector{T}, order, temp)
    min = max = by[v[i0]]
    @inbounds for i = i0+1:i1
        val = by[v[i]]
        if val < min
            min = val
        elseif val > max
            max = val
        end
    end
    rangelen = max-min+1
    n = i1-i0+1
    if rangelen <= n
        sort_int_range_sub_by!(v, i0-1, n, by, rangelen, min, temp)
    else
        empty!(temp)
        sort!(v, i0, i1, MergeSort, order, temp)
    end
    v
end

# in-place counting sort of x[ioffs+1:ioffs+n] by values in `by`
function sort_int_range_sub_by!(x, ioffs, n, by, rangelen, minval, temp)
    offs = 1 - minval

    where = fill(0, rangelen+1)
    where[1] = 1
    @inbounds for i = 1:n
        where[by[x[i+ioffs]] + offs + 1] += 1
    end
    cumsum!(where, where)

    length(temp) < n && resize!(temp, n)
    @inbounds for i = 1:n
        xi = x[i+ioffs]
        label = by[xi] + offs
        wl = where[label]
        temp[wl] = xi
        where[label] = wl+1
    end

    @inbounds for i = 1:n
        x[i+ioffs] = temp[i]
    end
    x
end
