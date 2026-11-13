# WorkManager (pulled in by google_mobile_ads) creates its Room database by
# reflection; R8 strips the generated class and the app crashes at startup on
# some devices ("Failed to create an instance of androidx.work.impl.WorkDatabase").
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
