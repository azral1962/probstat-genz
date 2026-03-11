import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import train_test_split
import seaborn as sns
import matplotlib.pyplot as plt

# 1. Data Latih (Kamus kita)
train_data = ["saya suka apel", "apel merah manis", "apel merah busuk", "saya benci apel merah"]
label = [1, 1, 0, 0]

vectorizer = CountVectorizer()

# 2. FIT: Mempelajari kosakata (saya, suka, apel, merah, manis)
vectorizer.fit(train_data)

# 3. TRANSFORM: Mengubah data baru menjadi angka
test_data = ["saya suka apel merah", "apel apel hijau"] # 'hijau' tidak ada di kamus
transformed_data = vectorizer.transform(test_data)

# Lihat hasilnya dalam bentuk array
print("Kosakata yang dipelajari:", vectorizer.get_feature_names_out())
print("Hasil transformasi:\n", transformed_data.toarray())