<script setup>
import ContactsCard from '../ContactsCard.vue';
import contacts from './fixtures';
</script>

<template>
  <Story
    title="Components/Contacts/ContactsCard"
    :layout="{ type: 'grid', width: '800px' }"
  >
    <Variant title="List">
      <div
        class="flex flex-col border divide-y rounded-xl border-n-weak divide-n-weak"
      >
        <ContactsCard
          v-for="contact in contacts"
          :key="contact.id"
          v-bind="contact"
          @show-contact="() => {}"
        />
      </div>
    </Variant>

    <Variant title="Without email and phone">
      <ContactsCard
        v-bind="{ ...contacts[3], email: '', phoneNumber: '' }"
        @show-contact="() => {}"
      />
    </Variant>
  </Story>
</template>
