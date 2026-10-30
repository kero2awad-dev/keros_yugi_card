-- 1. جدول الكروت (الأساسي)
CREATE TABLE IF NOT EXISTS public.cards (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT,
    frame_type TEXT,
    description TEXT,
    atk INTEGER,
    def INTEGER,
    level INTEGER,
    race TEXT,
    attribute TEXT,
    archetype TEXT,
    price DECIMAL DEFAULT 5.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. جدول المجموعات الجاهزة (Ready-made Decks)
CREATE TABLE IF NOT EXISTS public.ready_decks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    price DECIMAL NOT NULL,
    card_ids BIGINT[] NOT NULL, -- مصفوفة أرقام الكروت
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. جدول المجموعات الخاصة بالمستخدمين
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    style TEXT DEFAULT 'English',
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. جدول محتويات كل مجموعة
CREATE TABLE IF NOT EXISTS public.collection_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    collection_id UUID REFERENCES public.collections(id) ON DELETE CASCADE NOT NULL,
    card_id BIGINT REFERENCES public.cards(id) ON DELETE CASCADE NOT NULL,
    quantity INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. جدول المفضلة
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    card_id BIGINT REFERENCES public.cards(id) ON DELETE CASCADE NOT NULL,
    UNIQUE(user_id, card_id)
);

-- 6. جدول الطلبات (Orders)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    total_amount DECIMAL NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, confirmed, preparing, shipped, completed, cancelled
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. تفاصيل الطلب
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    collection_name TEXT,
    quantity INTEGER DEFAULT 1,
    price DECIMAL NOT NULL
);

-- إعدادات الحماية (RLS)
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read on cards" ON public.cards FOR SELECT USING (true);

ALTER TABLE public.ready_decks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read on ready_decks" ON public.ready_decks FOR SELECT USING (true);

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own collections" ON public.collections FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.collection_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own items" ON public.collection_items FOR ALL USING (
    EXISTS (SELECT 1 FROM public.collections WHERE id = collection_id AND user_id = auth.uid())
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own favorites" ON public.favorites FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can see their own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id);
